// Runs the assemble action of MSVC ABI toolchains.
//
// Bazel sends both raw GNU assembly (.s) and MASM (.asm) sources to the
// assemble action. clang-cl only understands GNU syntax and treats .asm files
// as such, while the MSVC and clang-cl toolchains of rules_cc assemble them
// with ml64.exe. MASM sources are therefore assembled with llvm-ml and all
// other sources with clang-cl, which receives the original arguments.

#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <process.h>
#else
#include <unistd.h>
#endif

static const char *required_env(const char *name) {
  const char *value = getenv(name);
  if (value == NULL || value[0] == '\0') {
    fprintf(stderr, "msvc-assembler: required env var %s is not set\n", name);
    exit(2);
  }
  return value;
}

static int is_masm_source(const char *path) {
  static const char extension[] = ".asm";
  size_t extension_length = sizeof(extension) - 1;
  size_t length = strlen(path);
  if (length < extension_length) {
    return 0;
  }
  const char *suffix = path + length - extension_length;
  for (size_t i = 0; i < extension_length; ++i) {
    if (tolower((unsigned char)suffix[i]) != extension[i]) {
      return 0;
    }
  }
  return 1;
}

static char *concat(const char *prefix, const char *value) {
  size_t prefix_length = strlen(prefix);
  size_t value_length = strlen(value);
  char *result = malloc(prefix_length + value_length + 1);
  if (result == NULL) {
    fprintf(stderr, "msvc-assembler: out of memory\n");
    exit(2);
  }
  memcpy(result, prefix, prefix_length);
  memcpy(result + prefix_length, value, value_length + 1);
  return result;
}

static int run(char *const args[]) {
#ifdef _WIN32
  intptr_t status = _spawnv(_P_WAIT, args[0], (const char *const *)args);
  if (status == -1) {
    fprintf(stderr, "msvc-assembler: failed to execute %s: %s\n", args[0],
            strerror(errno));
    return 2;
  }
  return (int)status;
#else
  execv(args[0], args);
  fprintf(stderr, "msvc-assembler: failed to execute %s: %s\n", args[0],
          strerror(errno));
  return 2;
#endif
}

int main(int argc, char **argv) {
  (void)argc;

  const char *source = getenv("LLVM_ASSEMBLE_SOURCE");
  if (source == NULL || !is_masm_source(source)) {
    argv[0] = (char *)required_env("LLVM_CLANG_CL");
    return run(argv);
  }

  // The arguments are meant for clang-cl, and llvm-ml doesn't read Bazel's
  // param files. Pass it only what it needs.
  const char *bitness = getenv("LLVM_ML_BITNESS");
  if (bitness == NULL || bitness[0] == '\0') {
    fprintf(stderr,
            "msvc-assembler: %s is a MASM source, but llvm-ml can only "
            "assemble MASM for x86_64 targets\n",
            source);
    return 1;
  }
  char *args[] = {
      (char *)required_env("LLVM_ML"),
      concat("-m", bitness),
      "/c",
      concat("/Fo", required_env("LLVM_ASSEMBLE_OUTPUT")),
      concat("/Ta", source),
      NULL,
  };
  return run(args);
}
