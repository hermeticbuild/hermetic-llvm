#include <stddef.h>
#include <stdlib.h>

// Declared here rather than via <sanitizer/asan_interface.h> to avoid a
// layering-check module dependency; the symbols come from the ASan runtime.
extern "C" {
void __asan_poison_memory_region(void const volatile *addr, size_t size);
void __asan_unpoison_memory_region(void const volatile *addr, size_t size);
int __asan_address_is_poisoned(void const volatile *addr);
}

// Verifies the ASan runtime is present and functional in a cc_test: a poisoned
// region must read back as poisoned. On macOS the runtime is a dylib, so this
// also proves the toolchain wired it into the test's runfiles.
int main(void) {
  char *buf = (char *)malloc(16);
  if (buf == NULL) {
    return 2;
  }
  __asan_poison_memory_region(buf, 16);
  int poisoned = __asan_address_is_poisoned(buf) != 0;
  __asan_unpoison_memory_region(buf, 16);
  free(buf);
  return poisoned ? 0 : 1;
}
