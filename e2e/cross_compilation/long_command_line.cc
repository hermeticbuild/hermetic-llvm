// Compiled with a command line longer than Windows' 32,767-character
// CreateProcessW limit; see :long_command_line in BUILD.bazel.

#ifndef PARAM_FILE_PADDING_1511
#error "the last padding define did not reach the compiler"
#endif

constexpr bool Equal(const char* a, const char* b) {
  return *a == *b && (*a == '\0' || Equal(a + 1, b + 1));
}

// Values that need quoting must survive the round trip through a param file.
static_assert(Equal(PARAM_FILE_SPACES, "two words"), "PARAM_FILE_SPACES");
static_assert(Equal(PARAM_FILE_QUOTES, "it's \"quoted\""), "PARAM_FILE_QUOTES");

int main() { return 0; }
