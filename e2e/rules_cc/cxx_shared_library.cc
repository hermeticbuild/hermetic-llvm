#include "cxx_shared_library.h"

Shape::~Shape() {}
int Shape::sides() const { return 0; }
int Shape::created = 0;
extern const int kPrimes[3] = {2, 3, 5};

int make_and_count() {
  Shape shape;
  return ++Shape::created + shape.sides();
}

void throw_out_of_range() { throw std::out_of_range("from shared library"); }
