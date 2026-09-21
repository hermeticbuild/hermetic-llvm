#include "tests/header_modules/counter.h"

void Counter::Increment() { ++value_; }

int Counter::Value() const { return value_; }
