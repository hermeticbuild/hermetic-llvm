#include "tests/header_modules/greeter.h"

namespace {
size_t count = 0;
}

std::string greet(const std::vector<std::string>& names) {
  ++count;
  std::string greeting = "Hello";
  for (const std::string& name : names) {
    greeting += ", " + name;
  }
  greeting += "!";
  return greeting;
}

size_t greeting_count() { return count; }
