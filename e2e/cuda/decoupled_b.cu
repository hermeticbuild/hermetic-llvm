#include <cuda_runtime.h>

__global__ void sub_b(int *p) { *p -= 5; }
__global__ void mul_b(int *p) { *p *= 2; }
extern "C" void launch_b(int *p) {
  sub_b<<<1, 1>>>(p);
  mul_b<<<1, 1>>>(p);
}
