// Wrapper around clang-scan-deps that produces the P1689 dependency
// information consumed by Bazel's C++20 modules support.
//
// Bazel invokes the `c++-module-deps-scanning` action with the same command
// line it would use for a regular C++ compilation. clang-scan-deps expects to
// be handed that compiler command line after a `--` separator and writes the
// P1689 JSON to stdout, so this wrapper rewrites
//
//     deps-scanner <compile flags...>
//
// into
//
//     clang-scan-deps -format=p1689 -- clang++ <compile flags...>
//
// redirecting stdout to the file named by DEPS_SCANNER_OUTPUT_FILE (set by the
// toolchain's compiler_output_flags for the scanning action). This mirrors the
// wrapper rules_cc generates for autoconfigured toolchains, but as a compiled
// tool to match the other internal wrappers (e.g. static_library_validator).

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <io.h>
#include <process.h>
#else
#include <unistd.h>
#endif

static const char *required_env(const char *name) {
  const char *value = getenv(name);
  if (value != NULL && value[0] != '\0') {
    return value;
  }
  fprintf(stderr, "deps_scanner: required env var %s is not set\n", name);
  exit(2);
}

int main(int argc, char **argv) {
  const char *scan_deps = required_env("LLVM_CLANG_SCAN_DEPS");
  const char *clangxx = required_env("LLVM_CLANGXX");
  const char *output = required_env("DEPS_SCANNER_OUTPUT_FILE");

  // clang-scan-deps writes the P1689 JSON to stdout; capture it in the file
  // Bazel declared as the action's output.
  if (freopen(output, "w", stdout) == NULL) {
    fprintf(stderr, "deps_scanner: failed to open %s: %s\n", output,
            strerror(errno));
    return 2;
  }

  // clang-scan-deps -format=p1689 -- clang++ <compile flags...>
  // argv[0] is this wrapper; argv[1..] are the compiler flags to forward.
  size_t prefix = 4;  // scan_deps, -format=p1689, --, clangxx
  char **child_argv = calloc((size_t)argc + prefix, sizeof(*child_argv));
  if (child_argv == NULL) {
    fprintf(stderr, "deps_scanner: out of memory\n");
    return 2;
  }
  size_t n = 0;
  child_argv[n++] = (char *)scan_deps;
  child_argv[n++] = (char *)"-format=p1689";
  child_argv[n++] = (char *)"--";
  child_argv[n++] = (char *)clangxx;
  for (int i = 1; i < argc; ++i) {
    child_argv[n++] = argv[i];
  }
  child_argv[n] = NULL;

#if defined(_WIN32)
  intptr_t status = _spawnv(_P_WAIT, scan_deps,
                           (const char *const *)child_argv);
  if (status < 0) {
    fprintf(stderr, "deps_scanner: _spawnv(%s): %s\n", scan_deps,
            strerror(errno));
    return 2;
  }
  return (int)status;
#else
  execv(scan_deps, child_argv);
  fprintf(stderr, "deps_scanner: execv(%s): %s\n", scan_deps, strerror(errno));
  return 2;
#endif
}
