#include <cstdio>
#include <string>

#include "greeting.h"

int main() {
  std::string greeting = Greet({"header", "modules"});
  std::printf("%s\n", greeting.c_str());
  return greeting == "Hello, header, modules!" ? 0 : 1;
}
