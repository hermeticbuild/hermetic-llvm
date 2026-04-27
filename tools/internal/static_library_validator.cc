#include <algorithm>
#include <cctype>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sstream>
#include <string>
#include <vector>

#if defined(_WIN32)
  #ifndef NOMINMAX
  #define NOMINMAX
  #endif
  #include <windows.h>
  #include <process.h>
  #include <io.h>
#else
  #include <sys/wait.h>
  #include <unistd.h>
#endif

struct SymbolEntry {
  std::string symbol;
  std::string object;
  char type;
};

static void PrintErrno(const char *what) {
  fprintf(stderr, "static_library_validator: %s: %s\n", what, strerror(errno));
}

static bool ShouldKeepType(char type) {
  return std::isupper(static_cast<unsigned char>(type)) &&
         type != 'U' && type != 'V' && type != 'W' && type != 'C';
}

#if defined(_WIN32)

// ---- Windows helpers ----

static std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return std::wstring();
  int len = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
  if (len <= 0) return std::wstring();
  std::wstring w(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), w.data(), len);
  return w;
}

static bool ExecWithPipes(const std::vector<std::string> &argv,
                          const std::string &stdin_data,
                          std::string *stdout_data) {
  int in_pipe[2], out_pipe[2];
  if (_pipe(in_pipe, 4096, _O_BINARY | _O_NOINHERIT) != 0) {
    PrintErrno("_pipe(stdin)");
    return false;
  }
  if (_pipe(out_pipe, 4096, _O_BINARY | _O_NOINHERIT) != 0) {
    PrintErrno("_pipe(stdout)");
    _close(in_pipe[0]); _close(in_pipe[1]);
    return false;
  }

  // Allow the child to inherit only the desired pipe ends.
  SetHandleInformation((HANDLE)_get_osfhandle(in_pipe[0]),
                       HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
  SetHandleInformation((HANDLE)_get_osfhandle(out_pipe[1]),
                       HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);

  int saved_in = _dup(_fileno(stdin));
  int saved_out = _dup(_fileno(stdout));
  if (saved_in < 0 || saved_out < 0) {
    PrintErrno("_dup");
    if (saved_in >= 0) _close(saved_in);
    if (saved_out >= 0) _close(saved_out);
    _close(in_pipe[0]); _close(in_pipe[1]);
    _close(out_pipe[0]); _close(out_pipe[1]);
    return false;
  }

  if (_dup2(in_pipe[0], _fileno(stdin)) != 0 ||
      _dup2(out_pipe[1], _fileno(stdout)) != 0) {
    PrintErrno("_dup2");
    _dup2(saved_in, _fileno(stdin));
    _dup2(saved_out, _fileno(stdout));
    _close(saved_in); _close(saved_out);
    _close(in_pipe[0]); _close(in_pipe[1]);
    _close(out_pipe[0]); _close(out_pipe[1]);
    return false;
  }

  std::vector<std::wstring> wargs;
  std::vector<const wchar_t *> wargv;
  wargs.reserve(argv.size());
  wargv.reserve(argv.size() + 1);
  for (const auto &a : argv) {
    wargs.push_back(Utf8ToWide(a));
    wargv.push_back(wargs.back().c_str());
  }
  wargv.push_back(nullptr);

  intptr_t child = _wspawnv(_P_NOWAIT, wargv[0], wargv.data());

  _dup2(saved_in, _fileno(stdin));
  _dup2(saved_out, _fileno(stdout));
  _close(saved_in); _close(saved_out);
  _close(in_pipe[0]); _close(out_pipe[1]);

  if (child == -1) {
    PrintErrno("_wspawnv");
    _close(in_pipe[1]); _close(out_pipe[0]);
    return false;
  }

  // Write stdin_data to child's stdin.
  size_t total_written = 0;
  while (total_written < stdin_data.size()) {
    int chunk = _write(in_pipe[1],
                       stdin_data.data() + total_written,
                       (unsigned int)(stdin_data.size() - total_written));
    if (chunk < 0) {
      PrintErrno("_write");
      _close(in_pipe[1]); _close(out_pipe[0]);
      int status = 0;
      _cwait(&status, child, 0);
      return false;
    }
    total_written += static_cast<size_t>(chunk);
  }
  _close(in_pipe[1]);

  stdout_data->clear();
  char buf[4096];
  while (true) {
    int n = _read(out_pipe[0], buf, sizeof(buf));
    if (n == 0) break;
    if (n < 0) {
      PrintErrno("_read");
      _close(out_pipe[0]);
      int status = 0;
      _cwait(&status, child, 0);
      return false;
    }
    stdout_data->append(buf, buf + n);
  }
  _close(out_pipe[0]);

  int status = 0;
  if (_cwait(&status, child, 0) == -1) {
    PrintErrno("_cwait");
    return false;
  }
  if (status != 0) {
    fprintf(stderr,
            "static_library_validator: command exited with status %d\n",
            status);
    return false;
  }
  return true;
}

#else

// ---- POSIX implementation ----

static bool ExecWithPipes(const std::vector<std::string> &argv,
                          const std::string &stdin_data,
                          std::string *stdout_data) {
  int in_pipe[2], out_pipe[2];
  if (pipe(in_pipe) != 0) return PrintErrno("pipe"), false;
  if (pipe(out_pipe) != 0) {
    PrintErrno("pipe");
    close(in_pipe[0]); close(in_pipe[1]);
    return false;
  }

  pid_t pid = fork();
  if (pid < 0) {
    PrintErrno("fork");
    close(in_pipe[0]); close(in_pipe[1]);
    close(out_pipe[0]); close(out_pipe[1]);
    return false;
  }

  if (pid == 0) {
    dup2(in_pipe[0], STDIN_FILENO);
    dup2(out_pipe[1], STDOUT_FILENO);
    close(in_pipe[0]); close(in_pipe[1]);
    close(out_pipe[0]); close(out_pipe[1]);
    std::vector<char *> args;
    args.reserve(argv.size() + 1);
    for (const auto &s : argv) args.push_back(const_cast<char *>(s.c_str()));
    args.push_back(nullptr);
    execv(args[0], args.data());
    fprintf(stderr, "static_library_validator: execv(%s): %s\n",
            args[0], strerror(errno));
    _exit(127);
  }

  close(in_pipe[0]);
  close(out_pipe[1]);

  ssize_t written = 0;
  while (written < static_cast<ssize_t>(stdin_data.size())) {
    ssize_t n = write(in_pipe[1], stdin_data.data() + written,
                      stdin_data.size() - written);
    if (n < 0) {
      if (errno == EINTR) continue;
      PrintErrno("write");
      close(in_pipe[1]); close(out_pipe[0]);
      return false;
    }
    written += n;
  }
  close(in_pipe[1]);

  stdout_data->clear();
  char buf[4096];
  while (true) {
    ssize_t n = read(out_pipe[0], buf, sizeof(buf));
    if (n == 0) break;
    if (n < 0) {
      if (errno == EINTR) continue;
      PrintErrno("read");
      close(out_pipe[0]);
      return false;
    }
    stdout_data->append(buf, n);
  }
  close(out_pipe[0]);

  int status = 0;
  if (waitpid(pid, &status, 0) < 0) {
    PrintErrno("waitpid");
    return false;
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    fprintf(stderr,
            "static_library_validator: command exited with status %d\n",
            WIFEXITED(status) ? WEXITSTATUS(status) : -1);
    return false;
  }
  return true;
}

#endif

static void ParseNmLine(const std::string &line,
                        std::vector<SymbolEntry> *out) {
  size_t open = line.find('[');
  size_t close = line.find(']', open == std::string::npos ? 0 : open + 1);
  size_t sep = line.find("]: ", close == std::string::npos ? 0 : close);
  if (open == std::string::npos || close == std::string::npos ||
      sep == std::string::npos) {
    return;
  }
  std::string object = line.substr(open + 1, close - open - 1);
  std::istringstream rest(line.substr(sep + 3));
  std::string symbol, type_str, dummy1, dummy2;
  if (!(rest >> symbol >> type_str >> dummy1 >> dummy2)) return;
  if (type_str.size() != 1) return;
  char type = type_str[0];
  if (!ShouldKeepType(type)) return;
  out->push_back({symbol, object, type});
}

static bool Touch(const char *path) {
  FILE *f = fopen(path, "ab");
  if (!f) return PrintErrno("fopen"), false;
  if (fclose(f) != 0) return PrintErrno("fclose"), false;
  return true;
}

static std::string RequiredEnv(const char *env_name) {
  const char *from_env = getenv(env_name);
  if (from_env && from_env[0] != '\0') {
    return from_env;
  }
  fprintf(stderr, "static_library_validator: required env var %s is not set\n",
          env_name);
  exit(2);
}

int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr,
            "usage: static_library_validator <static_library> <stamp_path>\n");
    return 2;
  }

  std::vector<std::string> nm_args = {
      RequiredEnv("LLVM_NM"),
      "-A",
      "-g",
      "-P",
  };
  const char *darwin_target = getenv("DARWIN_TARGET");
  if (darwin_target && strcmp(darwin_target, "1") == 0) {
    nm_args.push_back("--no-weak");
  }
  nm_args.push_back(argv[1]);

  std::string nm_output;
  if (!ExecWithPipes(nm_args, "", &nm_output)) return 2;

  std::vector<SymbolEntry> entries;
  std::istringstream nm_stream(nm_output);
  std::string line;
  while (std::getline(nm_stream, line)) {
    ParseNmLine(line, &entries);
  }

  std::sort(entries.begin(), entries.end(),
            [](const SymbolEntry &a, const SymbolEntry &b) {
              return a.symbol < b.symbol;
            });

  std::vector<std::string> dup_lines;
  for (size_t i = 0; i < entries.size();) {
    size_t j = i + 1;
    while (j < entries.size() && entries[j].symbol == entries[i].symbol) ++j;
    if (j - i >= 2) {
      for (size_t k = i; k < j; ++k) {
        dup_lines.push_back(entries[k].object + ": " +
                            std::string(1, entries[k].type) + " " +
                            entries[k].symbol);
      }
    }
    i = j;
  }

  if (dup_lines.empty()) return Touch(argv[2]) ? 0 : 2;

  std::string dup_block;
  for (const auto &l : dup_lines) dup_block.append(l).push_back('\n');

  std::string demangled;
  std::vector<std::string> filt_args = {
      RequiredEnv("LLVM_CXXFILT"),
  };
  if (!ExecWithPipes(filt_args, dup_block, &demangled)) return 2;

  fprintf(stderr, "Duplicate symbols found in %s:\n", argv[1]);
  fwrite(demangled.data(), 1, demangled.size(), stderr);
  return 1;
}
