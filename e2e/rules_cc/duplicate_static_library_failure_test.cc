#include <stdio.h>
#include <stdlib.h>

#include <fstream>
#include <iterator>
#include <memory>
#include <string>

#include "tools/cpp/runfiles/runfiles.h"

#if defined(_WIN32)
#include <io.h>
#define ACCESS _access
#else
#include <unistd.h>
#define ACCESS access
#endif

using bazel::tools::cpp::runfiles::Runfiles;

static const char *RequiredEnv(const char *name) {
  const char *value = getenv(name);
  if (value == nullptr || value[0] == '\0') {
    fprintf(stderr, "required env var %s is not set\n", name);
    exit(2);
  }
  return value;
}

static std::string Resolve(const Runfiles &runfiles, const char *name) {
  std::string path = runfiles.Rlocation(RequiredEnv(name));
  if (path.empty() || ACCESS(path.c_str(), 0) != 0) {
    fprintf(stderr, "could not find %s in runfiles: %s\n", name,
            path.c_str());
    exit(2);
  }
  return path;
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

static std::string ReadFile(const std::string &path) {
  std::ifstream file(path);
  return std::string(std::istreambuf_iterator<char>(file),
                     std::istreambuf_iterator<char>());
}

static int Validate(const std::string &validator, const std::string &archive,
                    const std::string &stamp, const std::string &log) {
  std::string command = "\"" + validator + "\" \"" + archive + "\" \"" +
                        stamp + "\" >\"" + log + "\" 2>&1";
#if defined(_WIN32)
  // cmd.exe needs another pair of quotes when the executable path is quoted.
  command = "\"" + command + "\"";
#endif
  return system(command.c_str());
}

int main() {
  std::string error;
  std::unique_ptr<Runfiles> runfiles(Runfiles::CreateForTest(&error));
  if (runfiles == nullptr) {
    fprintf(stderr, "failed to create runfiles: %s\n", error.c_str());
    return 2;
  }

  const std::string validator = Resolve(*runfiles, "VALIDATOR");
  const std::string nm = Resolve(*runfiles, "NM");
  const std::string cxxfilt = Resolve(*runfiles, "CXXFILT");
  const std::string duplicate = Resolve(*runfiles, "DUPLICATE_ARCHIVE");
  const std::string valid = Resolve(*runfiles, "VALID_ARCHIVE");
  const std::string tmpdir = RequiredEnv("TEST_TMPDIR");
#if defined(_WIN32)
  const char *separator = "\\";
#else
  const char *separator = "/";
#endif
  const std::string stamp = tmpdir + separator + "validation.txt";
  const std::string log = tmpdir + separator + "validation.log";

  SetEnv("LLVM_NM", nm);
  SetEnv("LLVM_CXXFILT", cxxfilt);
#if defined(__APPLE__)
  SetEnv("DARWIN_TARGET", "1");
#endif

  if (Validate(validator, duplicate, stamp, log) == 0) {
    fprintf(stderr, "duplicate archive unexpectedly passed validation\n");
    return 1;
  }
  std::string output = ReadFile(log);
  if (output.find("Duplicate symbols found") == std::string::npos ||
      output.find("duplicated_function") == std::string::npos ||
      output.find("duplicate_symbol_a") == std::string::npos ||
      output.find("duplicate_symbol_b") == std::string::npos ||
      ACCESS(stamp.c_str(), 0) == 0) {
    fprintf(stderr, "unexpected duplicate archive result:\n%s\n", output.c_str());
    return 1;
  }

  if (Validate(validator, valid, stamp, log) != 0 ||
      ACCESS(stamp.c_str(), 0) != 0) {
    fprintf(stderr, "valid archive failed validation:\n%s\n",
            ReadFile(log).c_str());
    return 1;
  }

  printf("static library validator accepted a valid archive and rejected "
         "duplicate symbols\n");
  return 0;
}
