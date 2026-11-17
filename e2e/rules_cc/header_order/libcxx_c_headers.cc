#include <cerrno>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <cwctype>

static_assert(sizeof(std::size_t) >= sizeof(void*));
static_assert(sizeof(decltype(&std::memcpy)) > 0);
static_assert(sizeof(decltype(&std::wcslen)) > 0);
static_assert(sizeof(decltype(&std::iswalpha)) > 0);

#ifndef EDOM
#error libc++ did not reach the C errno declarations
#endif

std::FILE* libcxx_c_file = nullptr;
