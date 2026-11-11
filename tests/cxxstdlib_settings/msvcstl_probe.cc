#include <cstdio>
#include <string>

#ifndef _MSVC_STL_VERSION
#error Expected the Microsoft STL headers
#endif

extern "C" int msvcstl_probe(int value) {
  const auto text = std::to_string(value);
  return std::printf("%s\n", text.c_str()) < 0 ? -1 : value;
}
