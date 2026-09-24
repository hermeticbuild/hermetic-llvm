#include <cuda_runtime.h>

// Exercise nonzero wrapper offsets and section-symbol relocation addends.
#ifndef __CUDA_ARCH__
asm(".pushsection .nvFatBinSegment,\"aw\",%progbits\n"
    ".balign 8\n.zero 32\n.popsection\n"
    ".pushsection .nv_fatbin,\"a\",%progbits\n"
    ".balign 8\n.zero 16\n.popsection\n");
#endif

__global__ void add_a(int *p) { *p += 7; }
__global__ void mul_a(int *p) { *p *= 3; }
extern "C" void launch_a(int *p) {
  add_a<<<1, 1>>>(p);
  mul_a<<<1, 1>>>(p);
}
