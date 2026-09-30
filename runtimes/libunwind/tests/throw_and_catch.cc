#include <cstdio>
#include <cstring>
#include <stdexcept>

#include "runtimes/libunwind/tests/thrower.h"

int main() {
  try {
    throw_from_shared_library();
  } catch (const std::runtime_error& error) {
    if (std::strcmp(error.what(), "from shared library") != 0) {
      std::fprintf(stderr, "unexpected what(): %s\n", error.what());
      return 1;
    }
    std::printf("exception caught\n");
    return 0;
  }
  std::fprintf(stderr, "no exception caught\n");
  return 1;
}
