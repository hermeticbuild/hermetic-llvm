#include <iostream>
#include <stdexcept>
#include <string>

extern "C" void throw_from_dso();

int main() {
  try {
    throw_from_dso();
  } catch (const std::runtime_error &error) {
    if (std::string(error.what()) == "cross-DSO exception") {
      std::cout << "Hello, World!" << std::endl;
      return 0;
    }
  }
  return 1;
}
