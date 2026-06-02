#include <stdio.h>
#include <stdlib.h>

#include <fstream>
#include <string>

#include "tools/cpp/runfiles/runfiles.h"

#if defined(_WIN32)
#include <direct.h>
#include <process.h>
#include <stdlib.h>
#define chdir _chdir
#define getcwd _getcwd
#define getpid _getpid
#define PATH_SEP "\\"
#define REDIRECT " > "
#else
#include <unistd.h>
#define PATH_SEP "/"
#define REDIRECT " > "
#endif

using bazel::tools::cpp::runfiles::Runfiles;

static std::string RequiredEnv(const char *name) {
  const char *value = getenv(name);
  if (value == nullptr || value[0] == '\0') {
    fprintf(stderr, "required env var %s is not set\n", name);
    exit(2);
  }
  return value;
}

static bool FileContains(const std::string &path, const char *needle) {
  std::ifstream file(path);
  std::string line;
  while (std::getline(file, line)) {
    if (line.find(needle) != std::string::npos) return true;
  }
  return false;
}

static void SetEnv(const char *name, const std::string &value) {
#if defined(_WIN32)
  if (_putenv_s(name, value.c_str()) != 0) {
#else
  if (setenv(name, value.c_str(), 1) != 0) {
#endif
    perror("setenv");
    exit(2);
  }
}

static void ClearEnv(const char *name) {
#if defined(_WIN32)
  if (_putenv_s(name, "") != 0) {
#else
  if (unsetenv(name) != 0) {
#endif
    perror("unsetenv");
    exit(2);
  }
}

static std::string SourceDir() {
  std::string error;
  std::unique_ptr<Runfiles> runfiles(Runfiles::CreateForTest(&error));
  if (runfiles == nullptr) {
    fprintf(stderr, "failed to create runfiles: %s\n", error.c_str());
    exit(2);
  }
  std::string path =
      runfiles->Rlocation(RequiredEnv("TEST_WORKSPACE") + "/BUILD.bazel");
  if (path.empty()) {
    fprintf(stderr, "failed to find BUILD.bazel in runfiles\n");
    exit(2);
  }
  size_t slash = path.find_last_of("/\\");
  if (slash == std::string::npos) {
    fprintf(stderr, "failed to determine source directory from %s\n",
            path.c_str());
    exit(2);
  }
  return path.substr(0, slash);
}

static std::string NestedBazelArgs() {
#if defined(_WIN32)
  // Do not let the inner Bazel inherit TEST_TMPDIR as its output root. Bazel
  // nests another full output tree under it, and on Windows that is enough to
  // push tool paths past what lld can handle.
  const char *tmp = getenv("TEMP");
  if (tmp == nullptr || tmp[0] == '\0') {
    tmp = getenv("TMP");
  }
  if (tmp == nullptr || tmp[0] == '\0') {
    tmp = getenv("TEST_TMPDIR");
  }
  if (tmp == nullptr || tmp[0] == '\0') {
    fprintf(stderr, "no temporary directory available for nested bazel\n");
    exit(2);
  }
  return " --output_user_root=\"" + std::string(tmp) +
         PATH_SEP + "duplicate_static_library_validator_" +
         std::to_string(getpid()) + "\"";
#else
  return "";
#endif
}

int main() {
  std::string log = RequiredEnv("TEST_TMPDIR") + PATH_SEP +
                    "duplicate_static_library.log";
  const char *bazel_bin = getenv("BAZEL_BIN");
  if (bazel_bin == nullptr || bazel_bin[0] == '\0') {
#if defined(_WIN32)
    bazel_bin = "bazel.exe";
#else
    bazel_bin = "bazel";
#endif
  }

  std::string source_dir = SourceDir();
  if (chdir(source_dir.c_str()) != 0) {
    perror("chdir");
    return 2;
  }
  SetEnv("HOME", RequiredEnv("TEST_TMPDIR"));
  // Bazel also treats TEST_TMPDIR as a default output root. Leave HOME pointing
  // at the test's private directory, but keep the nested Bazel from growing its
  // output base inside the outer test's temp directory.
  ClearEnv("TEST_TMPDIR");

  std::string command = std::string(bazel_bin) + NestedBazelArgs() +
                        " --bazelrc=.bazelrc build --color=yes --curses=yes"
                        " //:duplicate_symbol_lib" +
                        REDIRECT + "\"" + log + "\" 2>&1";
  int status = system(command.c_str());
  if (status == 0) {
    fprintf(stderr,
            "Expected duplicate_symbol_lib to fail duplicate symbol "
            "validation, but build succeeded.\n");
    return 1;
  }

  if (!FileContains(log, "Duplicate symbols found")) {
    fprintf(stderr, "Build failed, but duplicate symbol message not found.\n");
    char cwd[4096];
    if (getcwd(cwd, sizeof(cwd)) != nullptr) {
      fprintf(stderr, "cwd: %s\n", cwd);
    }
    fprintf(stderr, "command: %s\n", command.c_str());
    std::ifstream file(log);
    std::string line;
    while (std::getline(file, line)) {
      fprintf(stderr, "%s\n", line.c_str());
    }
    return 1;
  }

  printf("duplicate_static_library_validator_test: detected duplicate "
         "symbols as expected.\n");
  return 0;
}
