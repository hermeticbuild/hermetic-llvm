// Writes the toolchain's Clang module map. Textual headers are declared with
// their size so that Clang resolves them lazily (only when a file of that size
// is included). Each header has its own submodule: when a textual header
// includes another header, Clang's ModuleMap::diagnoseHeaderInclusion resolves
// every header in the requesting module, regardless of size. A flat module
// would therefore still stat every declared header during compilation.
//
// Usage: module_map_generator <output> @<params>
//
// The params file contains one header path per line, relative to the working
// directory.

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <sys/stat.h>
#endif

#if defined(_WIN32)
static wchar_t *utf8_to_wide(const char *value) {
  // UTF-16 never needs more code units than UTF-8 needs bytes.
  size_t capacity = strlen(value) + 1;
  if (capacity > INT_MAX) {
    errno = ENAMETOOLONG;
    return NULL;
  }
  wchar_t *wide = malloc(capacity * sizeof(wchar_t));
  if (wide == NULL) {
    errno = ENOMEM;
    return NULL;
  }
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, wide,
                          (int)capacity) == 0) {
    free(wide);
    errno = EINVAL;
    return NULL;
  }
  return wide;
}

// Windows rejects paths of MAX_PATH (260) or more characters unless they are
// absolute and start with \\?\, and a header deep in a Bazel output directory
// can exceed that limit. The prefix also turns off Windows' normalization of
// separators and dot segments, so normalize the path first.
static wchar_t *extended_length_path(const char *path) {
  wchar_t *wide = utf8_to_wide(path);
  if (wide == NULL) {
    return NULL;
  }
  DWORD full_length = GetFullPathNameW(wide, 0, NULL, NULL);
  if (full_length == 0) {
    free(wide);
    errno = EINVAL;
    return NULL;
  }
  wchar_t *full = malloc(full_length * sizeof(wchar_t));
  if (full == NULL) {
    free(wide);
    errno = ENOMEM;
    return NULL;
  }
  DWORD written = GetFullPathNameW(wide, full_length, full, NULL);
  free(wide);
  if (written == 0 || written >= full_length) {
    free(full);
    errno = EINVAL;
    return NULL;
  }

  const wchar_t *prefix = L"\\\\?\\";
  const wchar_t *rest = full;
  if (full[0] == L'\\' && full[1] == L'\\') {
    // \\server\share\path becomes \\?\UNC\server\share\path.
    prefix = L"\\\\?\\UNC\\";
    rest = full + 2;
  }
  size_t extended_length = wcslen(prefix) + wcslen(rest) + 1;
  wchar_t *extended = malloc(extended_length * sizeof(wchar_t));
  if (extended == NULL) {
    free(full);
    errno = ENOMEM;
    return NULL;
  }
  wcscpy(extended, prefix);
  wcscat(extended, rest);
  free(full);
  return extended;
}

static int file_size(const char *path, unsigned long long *size) {
  wchar_t *extended = extended_length_path(path);
  if (extended == NULL) {
    return -1;
  }
  WIN32_FILE_ATTRIBUTE_DATA data;
  BOOL found = GetFileAttributesExW(extended, GetFileExInfoStandard, &data);
  DWORD error = GetLastError();
  free(extended);
  if (!found) {
    switch (error) {
    case ERROR_FILE_NOT_FOUND:
    case ERROR_PATH_NOT_FOUND:
      errno = ENOENT;
      break;
    case ERROR_ACCESS_DENIED:
      errno = EACCES;
      break;
    default:
      errno = EIO;
      break;
    }
    return -1;
  }
  *size = ((unsigned long long)data.nFileSizeHigh << 32) | data.nFileSizeLow;
  return 0;
}
#else // !defined(_WIN32)
static int file_size(const char *path, unsigned long long *size) {
  struct stat st;
  if (stat(path, &st) != 0) {
    return -1;
  }
  *size = (unsigned long long)st.st_size;
  return 0;
}
#endif // defined(_WIN32)

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
    if (len != 0) {
      unsigned long long size;
      if (file_size(line, &size) != 0) {
        fprintf(stderr, "%s: %s\n", line, strerror(errno));
        status = 1;
        continue;
      }
      fprintf(output,
              "  module \"%s\" {\n"
              "    textual header \"%s\" { size %llu }\n"
              "  }\n",
              line, line, size);
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
