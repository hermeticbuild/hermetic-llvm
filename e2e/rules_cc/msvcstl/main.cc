#include <iostream>
#include <string>

#ifndef _MSVC_STL_VERSION
#error Expected the Microsoft STL headers
#endif

int main(int argc, char**) {
  std::cout << std::string(64, 'x') << argc << '\n';
}
