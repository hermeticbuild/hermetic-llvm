// With modules enabled, the SDK's __need_ptrdiff_t include must reach Clang's
// stddef.h through libc++'s include_next, before the SDK's own stddef.h.
#ifdef __APPLE__
#include <sys/_types.h>
#endif

#include <cstddef>
#include <stdarg.h>

int main() {
  static_assert(sizeof(std::ptrdiff_t) == sizeof(void*));
  return 0;
}
