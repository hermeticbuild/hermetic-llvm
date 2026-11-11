#include <iostream>
#include <string>

#ifndef _MSVC_STL_VERSION
#error Expected the Microsoft STL headers
#endif

int foreign_msvcstl(int value) {
  std::cout << std::to_string(value) << '\n';
  return value;
}
