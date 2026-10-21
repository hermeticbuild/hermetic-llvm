// Model Rust's libc binding: call the out-of-line definition without stdio.h's
// inline wrapper. Extracting it also requests legacy_stdio_wide_specifiers.lib.
#pragma comment(lib, "legacy_stdio_definitions.lib")
int sscanf(const char* buffer, const char* format, ...);

int windows_msvc_legacy_stdio(void) {
  int value = 0;
  return sscanf("42", "%d", &value) == 1 ? value : 0;
}
