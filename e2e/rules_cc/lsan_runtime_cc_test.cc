#include <stdlib.h>

// Declared here rather than via <sanitizer/lsan_interface.h> to avoid a
// layering-check module dependency; the symbol comes from the LSan runtime.
extern "C" {
int __lsan_do_recoverable_leak_check(void);
}

// Verifies the LSan runtime is present and functional in a cc_test: an
// intentional leak must be reported by a recoverable leak check. On macOS the
// runtime is a dylib, so this also proves the toolchain wired it into the
// test's runfiles. _Exit() skips the atexit leak check so the intentional leak
// doesn't fail the test a second time.
int main(void) {
  void *volatile sink = malloc(1337);
  (void)sink;
  sink = NULL;  // drop the only reference so the block is leaked
  int leaks = __lsan_do_recoverable_leak_check();
  _Exit(leaks ? 0 : 1);
}
