#include <stdio.h>

int panic_unwind_caught(void);

int main(void) {
  if (!panic_unwind_caught()) {
    return 1;
  }
  puts("caught");
  return 0;
}
