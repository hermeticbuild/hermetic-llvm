#include <cstdio>
#include <cstring>
#include <stdexcept>

#ifdef __MINGW32__
#include <windows.h>
#endif

#include "cxx_shared_library.h"

struct Square : Shape {
  int sides() const override { return 4; }
};

int main() {
  Square square;
  Shape* shape = &square;
  if (make_and_count() != 1 || Shape::created != 1 || shape->sides() != 4 ||
      kPrimes[2] != 5) {
    std::fprintf(stderr, "unexpected values\n");
    return 1;
  }
#ifdef __MINGW32__
  // Auto-export has to skip the statically linked C++ runtime.
  HMODULE library = GetModuleHandleA("libcxx_shared_library.dll");
  if (library == nullptr ||
      GetProcAddress(library, "_Z14make_and_countv") == nullptr ||
      GetProcAddress(library, "__cxa_throw") != nullptr ||
      GetProcAddress(library, "unw_getcontext") != nullptr) {
    std::fprintf(stderr, "unexpected exports\n");
    return 1;
  }
#endif
  try {
    throw_out_of_range();
  } catch (const std::out_of_range& e) {
    return std::strcmp(e.what(), "from shared library") == 0 ? 0 : 1;
  }
  std::fprintf(stderr, "exception not caught\n");
  return 1;
}
