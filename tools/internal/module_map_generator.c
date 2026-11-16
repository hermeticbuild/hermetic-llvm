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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <sys/stat.h>
#endif

#if defined(_WIN32)
// The most UTF-16 code units in a Windows path, including the terminator.
#define PATH_CAPACITY 32768

// Windows rejects paths of MAX_PATH (260) or more characters unless they are
// absolute and start with \\?\, and a header deep in a Bazel output directory
// can exceed that limit. The prefix also turns off Windows' normalization of
// separators and dot segments, so normalize the path first.
//
// Returns a static buffer, which the next call overwrites. The buffers are
// sized for the longest Windows path, so each step needs only one call.
static const wchar_t *extended_length_path(const char *path) {
  static wchar_t wide[PATH_CAPACITY];
  static wchar_t full[PATH_CAPACITY];
  static wchar_t extended[PATH_CAPACITY];

  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide,
                          PATH_CAPACITY) == 0) {
    errno = GetLastError() == ERROR_INSUFFICIENT_BUFFER ? ENAMETOOLONG : EINVAL;
    return NULL;
  }
  DWORD full_length = GetFullPathNameW(wide, PATH_CAPACITY, full, NULL);
  if (full_length == 0) {
    errno = EINVAL;
    return NULL;
  }
  if (full_length >= PATH_CAPACITY) {
    errno = ENAMETOOLONG;
    return NULL;
  }

  const wchar_t *prefix = L"\\\\?\\";
  const wchar_t *rest = full;
  if (full[0] == L'\\' && full[1] == L'\\') {
    // \\server\share\path becomes \\?\UNC\server\share\path.
    prefix = L"\\\\?\\UNC\\";
    rest = full + 2;
  }
  if (wcslen(prefix) + wcslen(rest) >= PATH_CAPACITY) {
    errno = ENAMETOOLONG;
    return NULL;
  }
  wcscpy(extended, prefix);
  wcscat(extended, rest);
  return extended;
}

static int file_size_error(DWORD error) {
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

static int file_size(const char *path, unsigned long long *size) {
  const wchar_t *extended = extended_length_path(path);
  if (extended == NULL) {
    return -1;
  }
  WIN32_FILE_ATTRIBUTE_DATA data;
  if (!GetFileAttributesExW(extended, GetFileExInfoStandard, &data)) {
    return file_size_error(GetLastError());
  }
  if (data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) {
    // Attribute queries describe the link itself. Open without
    // FILE_FLAG_OPEN_REPARSE_POINT to read the target's size, as stat does.
    HANDLE file =
        CreateFileW(extended, FILE_READ_ATTRIBUTES,
                    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                    NULL, OPEN_EXISTING, 0, NULL);
    if (file == INVALID_HANDLE_VALUE) {
      return file_size_error(GetLastError());
    }
    LARGE_INTEGER target_size;
    if (!GetFileSizeEx(file, &target_size)) {
      DWORD error = GetLastError();
      CloseHandle(file);
      return file_size_error(error);
    }
    CloseHandle(file);
    *size = (unsigned long long)target_size.QuadPart;
    return 0;
  }
  *size = ((unsigned long long)data.nFileSizeHigh << 32) | data.nFileSizeLow;
  return 0;
}
#else  // !defined(_WIN32)
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
