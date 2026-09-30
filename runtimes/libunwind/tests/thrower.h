#ifndef LLVM_RUNTIMES_LIBUNWIND_TESTS_THROWER_H_
#define LLVM_RUNTIMES_LIBUNWIND_TESTS_THROWER_H_

// Defined in a library that becomes its own shared object when the binary is
// linked with linkstatic = False, so the exception unwinds across a DSO
// boundary through the dynamic unwinder.
void throw_from_shared_library();

#endif  // LLVM_RUNTIMES_LIBUNWIND_TESTS_THROWER_H_
