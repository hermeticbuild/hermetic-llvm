#pragma once

#include "tests/header_modules/counter.h"

class DoubleCounter {
 public:
  void Increment() {
    counter_.Increment();
    counter_.Increment();
  }

  int Value() const { return counter_.Value(); }

 private:
  Counter counter_;
};
