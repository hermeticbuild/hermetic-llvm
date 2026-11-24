// Compiled with -fexceptions, so the cleanup runs through
// __gcc_personality_v0 when an exception unwinds this frame.

static void mark_cleaned(int **cleaned) { ++**cleaned; }

int run_with_cleanup(void (*fn)(void), int *cleaned) {
  int *flag __attribute__((cleanup(mark_cleaned))) = cleaned;
  fn();
  return *flag;
}
