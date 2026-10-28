#include <unistd.h>

// With glibc 2.17 headers, clang++ used to compile the FORTIFY readlink
// wrapper into a call to itself.
int main() {
  char buf[4096];
  ssize_t n = readlink("/proc/self/exe", buf, sizeof buf);
  return n > 0 && buf[0] == '/' ? 0 : 1;
}
