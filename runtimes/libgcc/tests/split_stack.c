// Built with -fsplit-stack, so function prologues call libgcc's __morestack
// when the stack runs low. libgcc_s.so.1 does not export __morestack; dynamic
// links find it in libgcc.a through the libgcc_s.so linker script.

#include <stdint.h>
#include <stdio.h>

static int stack_switches;

// 1024 calls with 4 KiB frames need 4 MiB of stack, more than one segment
// from __morestack holds. The function calls nothing but itself
// (no_stack_protector keeps __stack_chk_fail out), so lld keeps its split-stack
// prologue as compiled. A call to a function built without -fsplit-stack would
// make lld rewrite the prologue to call __morestack_non_split.
__attribute__((noinline, no_stack_protector)) static int recurse(int depth, uintptr_t caller_frame) {
  volatile char frame[4096];
  uintptr_t here = (uintptr_t)frame;
  // On one stack, each frame sits just below its caller's.
  if (caller_frame != 0 && (here > caller_frame || caller_frame - here > 64 * 1024)) {
    ++stack_switches;
  }
  frame[0] = 1;
  if (depth == 0) {
    return frame[0];
  }
  return recurse(depth - 1, here) + frame[0];
}

int main(void) {
  int calls = recurse(1023, 0);
  if (calls != 1024) {
    fprintf(stderr, "FAIL: recursion returned %d\n", calls);
    return 1;
  }
  if (stack_switches == 0) {
    fputs("FAIL: every frame was on one stack, so __morestack never ran\n", stderr);
    return 1;
  }
  return 0;
}
