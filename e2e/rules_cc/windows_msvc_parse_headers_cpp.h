#ifndef HERMETIC_LLVM_E2E_WINDOWS_MSVC_PARSE_HEADERS_CPP_H_
#define HERMETIC_LLVM_E2E_WINDOWS_MSVC_PARSE_HEADERS_CPP_H_

#include <cstddef>

#include "windows_msvc_libcxx_behavior_support.h"

static_assert(sizeof(std::size_t) == sizeof(void *));

inline int windows_msvc_parse_headers_cpp_probe() {
  return windows_msvc_ordinary_add(20, 22);
}

#endif
