#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <io.h>
#include <process.h>
#include <sys/stat.h>
#else
#include <unistd.h>
#endif

int main(int argc, char **argv) {
  const char *path = getenv("PARSE_HEADER");
  if (path == NULL || path[0] == '\0') {
    fprintf(stderr, "header_parser: required env var PARSE_HEADER is not set\n");
    exit(2);
  }

#ifdef _WIN32
  int fd = _open(path, _O_WRONLY | _O_CREAT | _O_BINARY,
                 _S_IREAD | _S_IWRITE);
#else
  int fd = open(path, O_WRONLY | O_CREAT, 0666);
#endif
  if (fd < 0) {
    fprintf(stderr, "header_parser: failed to touch %s: %s\n",
            path, strerror(errno));
    exit(2);
  }
#ifdef _WIN32
  if (_close(fd) != 0) {
#else
  if (close(fd) != 0) {
#endif
    fprintf(stderr, "header_parser: failed to close %s: %s\n",
            path, strerror(errno));
    exit(2);
  }

  const char *clang_path = getenv("LLVM_CLANGXX");
  if (clang_path == NULL || clang_path[0] == '\0') {
    fprintf(stderr, "header_parser: required env var LLVM_CLANGXX is not set\n");
    exit(2);
  }

  argv[0] = (char *)clang_path;
#ifdef _WIN32
  int status = _spawnv(_P_WAIT, clang_path, (const char *const *)argv);
  if (status == -1) {
    fprintf(stderr, "header_parser: _spawnv failed: %s\n", strerror(errno));
    return 2;
  }
  return status;
#else
  execv(clang_path, argv);
  fprintf(stderr, "header_parser: execv failed: %s\n", strerror(errno));
  return 2;
#endif
}
