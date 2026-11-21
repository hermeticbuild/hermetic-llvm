#include <stdio.h>

namespace {

int cleanups = 0;

struct Cleanup {
  ~Cleanup() { ++cleanups; }
};

// Throw through a frame with a destructor, so the unwinder runs both its
// search phase and a cleanup.
[[gnu::noinline]] void Throw(int value) {
  Cleanup cleanup;
  throw value;
}

}  // namespace

int main() {
  try {
    Throw(42);
  } catch (int value) {
    printf("caught %d after %d cleanup\n", value, cleanups);
    return value == 42 && cleanups == 1 ? 0 : 1;
  }
  return 1;
}
