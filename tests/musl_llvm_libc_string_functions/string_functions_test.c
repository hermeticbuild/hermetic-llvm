// Compares the string functions against naive implementations for all lengths
// and alignments up to a limit, also right before an inaccessible page.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/mman.h>
#include <unistd.h>

#define MAX_LEN 192
#define MAX_ALIGN 64

static int failures = 0;

#define CHECK(cond, ...)            \
  do {                              \
    if (!(cond)) {                  \
      fprintf(stderr, __VA_ARGS__); \
      fputc('\n', stderr);          \
      if (++failures > 20) exit(1); \
    }                               \
  } while (0)

static int sign(int x) { return (x > 0) - (x < 0); }

static int naive_memcmp(const char *a, const char *b, size_t n) {
  for (size_t i = 0; i < n; i++) {
    if (a[i] != b[i]) return (unsigned char)a[i] - (unsigned char)b[i];
  }
  return 0;
}

static void check_memcmp(const char *a, const char *b, size_t n) {
  int want = sign(naive_memcmp(a, b, n));
  CHECK(sign(memcmp(a, b, n)) == want, "memcmp(len=%zu) != %d", n, want);
  CHECK((bcmp(a, b, n) != 0) == (want != 0), "bcmp(len=%zu) != %d", n, want);
}

static void check_strlen(char *s, size_t n) {
  for (size_t i = 0; i < n; i++) s[i] = (char)('a' + i % 26);
  s[n] = 0;
  CHECK(strlen(s) == n, "strlen(len=%zu)", n);
}

int main(void) {
  static char a[MAX_ALIGN + MAX_LEN + 1], b[MAX_ALIGN + MAX_LEN + 1];
  for (size_t n = 0; n <= MAX_LEN; n++) {
    for (size_t align = 0; align < MAX_ALIGN; align++) {
      char *pa = a + align, *pb = b + (MAX_ALIGN - 1 - align);
      for (size_t i = 0; i < n; i++) pa[i] = pb[i] = (char)(i * 7);
      check_memcmp(pa, pb, n);
      for (size_t pos = 0; pos < n; pos++) {
        pb[pos] = (char)(pa[pos] + 1);
        check_memcmp(pa, pb, n);
        pb[pos] = (char)(pa[pos] - 1);
        check_memcmp(pa, pb, n);
        pb[pos] = pa[pos];
      }
      check_strlen(pa, n);
    }
  }

  // Ranges and strings that end right before an inaccessible page.
  long page = sysconf(_SC_PAGESIZE);
  char *pages = mmap(NULL, 2 * page, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  CHECK(pages != MAP_FAILED, "mmap failed");
  CHECK(mprotect(pages + page, page, PROT_NONE) == 0, "mprotect failed");
  char *end = pages + page;
  for (size_t n = 0; n <= MAX_LEN; n++) {
    char *p = end - n;
    memset(p, 'x', n);
    check_memcmp(p, p, n);
    if (n > 0) check_strlen(p, n - 1);
  }

  if (failures) return 1;
  puts("PASSED");
  return 0;
}
