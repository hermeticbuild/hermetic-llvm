#include <stdexcept>

extern "C" void throw_from_dso() {
  throw std::runtime_error("cross-DSO exception");
}
