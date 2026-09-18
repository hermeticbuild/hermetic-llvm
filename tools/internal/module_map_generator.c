// Writes the toolchain's Clang module map. Textual headers are declared with
// their size so that Clang resolves them lazily (only when a file of that size
// is included) instead of stat'ing every declared header whenever the module
// map is parsed.
//
// Usage: module_map_generator <output> @<params>
//
// The params file contains one entry per line: `umbrella <directory>` for a
// directory to cover with an umbrella submodule, or `textual <header>` for a
// header to declare as textual. Paths are relative to the working directory.

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#if defined(_WIN32)
#define stat_type struct __stat64
#define stat_fn _stat64
#else
#define stat_type struct stat
#define stat_fn stat
#endif

static int file_size(const char *path, unsigned long long *size) {
  stat_type st;
  if (stat_fn(path, &st) != 0) {
    return -1;
  }
  *size = (unsigned long long)st.st_size;
  return 0;
}

int main(int argc, char **argv) {
  if (argc != 3 || argv[2][0] != '@') {
    fprintf(stderr, "usage: %s <output> @<params>\n", argv[0]);
    return 2;
  }
  const char *output_path = argv[1];
  const char *params_path = argv[2] + 1;

  FILE *params = fopen(params_path, "rb");
  if (params == NULL) {
    fprintf(stderr, "%s: %s\n", params_path, strerror(errno));
    return 1;
  }
  FILE *output = fopen(output_path, "wb");
  if (output == NULL) {
    fprintf(stderr, "%s: %s\n", output_path, strerror(errno));
    return 1;
  }

  fputs("module \"crosstool\" [system] {\n", output);
  char *line = NULL;
  size_t cap = 0;
  int status = 0;
  for (;;) {
    int c;
    size_t len = 0;
    while ((c = fgetc(params)) != EOF && c != '\n') {
      if (len + 1 >= cap) {
        cap = cap == 0 ? 256 : cap * 2;
        line = realloc(line, cap);
        if (line == NULL) {
          fprintf(stderr, "out of memory\n");
          return 1;
        }
      }
      line[len++] = (char)c;
    }
    if (len == 0 && c == EOF) {
      break;
    }
    line[len] = '\0';
    if (strncmp(line, "umbrella ", 9) == 0) {
      const char *path = line + 9;
      fprintf(output, "  module \"%s\" {\n    umbrella \"%s\"\n  }\n", path, path);
    } else if (strncmp(line, "textual ", 8) == 0) {
      const char *path = line + 8;
      unsigned long long size;
      if (file_size(path, &size) != 0) {
        fprintf(stderr, "%s: %s\n", path, strerror(errno));
        status = 1;
        continue;
      }
      fprintf(output, "  textual header \"%s\" { size %llu }\n", path, size);
    } else if (len != 0) {
      fprintf(stderr, "unrecognized entry: %s\n", line);
      status = 1;
    }
    if (c == EOF) {
      break;
    }
  }
  fputs("}\n", output);
  free(line);
  fclose(params);
  if (fclose(output) != 0) {
    fprintf(stderr, "%s: %s\n", output_path, strerror(errno));
    return 1;
  }
  return status;
}
