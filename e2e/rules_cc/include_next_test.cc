#include <cstddef>

#ifndef HERMETIC_LLVM_DEPENDENCY_CSTDDEF
#error "dependency wrappers must precede toolchain headers"
#endif

int main() {
  std::size_t size = sizeof(std::max_align_t);
  return size == 0;
}
