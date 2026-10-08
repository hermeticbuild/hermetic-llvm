#include "runtimes/libunwind/tests/thrower.h"

#include <stdexcept>

void throw_from_shared_library() {
  throw std::runtime_error("from shared library");
}
