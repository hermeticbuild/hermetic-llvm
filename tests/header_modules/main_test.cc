#include "tests/header_modules/double_counter.h"

int main() {
  DoubleCounter counter;
  counter.Increment();
  counter.Increment();
  return counter.Value() == 4 ? 0 : 1;
}
