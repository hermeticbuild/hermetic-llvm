#include <sstream>

int main() {
    std::istringstream input("42");
    int value;
    // The library initializes value; its instrumentation must update MSan's shadow.
    input >> value;
    return value != 42;
}
