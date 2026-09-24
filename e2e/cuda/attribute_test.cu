#include "included.h"

#if CUDA_LIBRARY_HEADER != 7 || CUDA_LIBRARY_FORCED_INCLUDE != 11 || \
    CUDA_LIBRARY_DEFINE != 13 || CUDA_LIBRARY_LOCAL != 17
#error "cuda_library must forward compilation attributes to both CUDA passes"
#endif

__global__ void AttributeKernel(int *value) { *value = CUDA_LIBRARY_LOCAL; }

// No symbol from this file is referenced by main. Its constructor runs only
// if alwayslink reaches the library that actually owns the host object.
extern int cuda_library_registrations;
struct Register {
  Register() { ++cuda_library_registrations; }
};
static Register registration;
