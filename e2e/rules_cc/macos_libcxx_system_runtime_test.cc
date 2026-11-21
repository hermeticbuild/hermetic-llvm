#include <cxxabi.h>
#include <cstdlib>
#include <variant>

int main() {
  int status = -1;
  char* name = abi::__cxa_demangle("_Z3foov", nullptr, nullptr, &status);
  if (status != 0 || name == nullptr) return 1;
  std::free(name);

  std::variant<int, double> value(1);
  try {
    (void)std::get<double>(value);
  } catch (const std::bad_variant_access&) {
    return 0;
  }
  return 1;
}
