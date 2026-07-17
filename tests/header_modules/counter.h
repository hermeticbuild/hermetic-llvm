#pragma once

class Counter {
 public:
  void Increment();
  int Value() const;

 private:
  int value_ = 0;
};
