// Verifies the UBSan runtime is present in a cc_test. On macOS the standalone
// UBSan runtime is a load-time dylib dependency, so the test only runs if the
// toolchain wired it into the test's runfiles. The recoverable signed overflow
// also exercises the runtime's diagnostic path (non-fatal by default).
int main(int argc, char **argv) {
  (void)argv;
  int x = 0x7fffffff;
  x += argc;  // signed overflow -> UBSan diagnostic (recoverable)
  return x == argc ? 0 : 0;
}
