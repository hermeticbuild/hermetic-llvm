// Built with the no_exceptions feature and, in the runtime_no_exceptions
// variant, against libc++ and libc++abi compiled without exceptions.
// The allocation and the bounds-checked access are the two libc++ paths that
// throw when exceptions are on:
// * operator new's std::bad_alloc from libc++abi
// * __throw_out_of_range from libc++
// The test inspects the binary's symbol table, it does not run it.
// The default link (with exceptions) defines
// __cxa_throw, the flagged link (with -fno-exceptions) defines
// none of __cxa_throw, __cxa_begin_catch or __gxx_personality_v0.
#include <vector>

int main(int argc, char **) {
  std::vector<int> v(static_cast<unsigned>(argc));
  return v.at(static_cast<unsigned>(argc) + 5);
}
