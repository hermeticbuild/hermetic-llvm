#include <threads.h>
#include <windows.h>

// Rust's libc crate adds this library to every MSVC link that depends on libc.
#pragma comment(lib, "legacy_stdio_definitions.lib")

int windows_msvc_c_smoke(void) {
  const thrd_t current = thrd_current();
  return GetCurrentProcessId() != 0 && thrd_equal(current, current) ? 42 : 0;
}
