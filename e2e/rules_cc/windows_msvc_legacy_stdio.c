// Model Rust's libc binding: declare sscanf without compiling stdio.h's
// implementation. The linker must use legacy_stdio_definitions.lib's
// implementation, which also requests legacy_stdio_wide_specifiers.lib.
#pragma comment(lib, "legacy_stdio_definitions.lib")
int sscanf(const char* buffer, const char* format, ...);

int main(void) {
  int value = 0;
  return sscanf("42", "%d", &value) != 1 || value != 42;
}
