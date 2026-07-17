#include <cstdio>
#include <string>
#include <vector>

#include "tests/header_modules/greeter.h"

int main() {
  std::string greeting = greet({"header", "modules"});
  std::printf("%s\n", greeting.c_str());
  return greeting == "Hello, header, modules!" && greeting_count() == 1 ? 0
                                                                        : 1;
}
