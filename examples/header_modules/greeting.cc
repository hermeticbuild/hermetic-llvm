#include "greeting.h"

std::string Greet(const std::vector<std::string>& names) {
  std::string greeting = "Hello";
  for (const std::string& name : names) {
    greeting += ", " + name;
  }
  greeting += "!";
  return greeting;
}
