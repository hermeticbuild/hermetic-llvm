#include <stddef.h>
#include <stdio.h>

#include "replacement.h"

#ifdef EXPECT_NO_CXX_HEADERS
#if __has_include(<vector>)
#error Default C++ headers must not be visible with nostdincxx
#endif
#else
#include <type_traits>
static_assert(std::is_integral<int>::value, "default C++ headers are available");
#endif

int main() {
  // Exercise an explicitly supplied header and C++ archive, plus the C runtime,
  // with each independent setting combination.
  printf("replacement runtime: %d\n", replacement_value());
  return replacement_value() == 42 ? 0 : 1;
}
