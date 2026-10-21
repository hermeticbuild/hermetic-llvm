#include <threads.h>
#include <windows.h>

// Rust's libc crate adds this library to every MSVC link that depends on libc.
#pragma comment(lib, "legacy_stdio_definitions.lib")

// Match an FFI binding: call the out-of-line definition, without stdio.h's
// inline wrapper. Extracting it also requests legacy_stdio_wide_specifiers.lib.
int sscanf(const char* buffer, const char* format, ...);

int windows_msvc_c_smoke(void) {
  int value = 0;
  if (sscanf("42", "%d", &value) != 1 || value != 42) {
    return 0;
  }
  const thrd_t current = thrd_current();
  return GetCurrentProcessId() != 0 && thrd_equal(current, current) ? 42 : 0;
}
