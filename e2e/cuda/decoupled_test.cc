#include <cstdio>
#include <cuda_runtime.h>

extern "C" void launch_a(int *);
extern "C" void launch_b(int *);
extern "C" int cpu_only_value();
#define CHECK(call)                                                            \
  do {                                                                         \
    cudaError_t error = (call);                                                \
    if (error != cudaSuccess) {                                                \
      std::fprintf(stderr, "%s: %s\n", #call, cudaGetErrorString(error));      \
      return 1;                                                                \
    }                                                                          \
  } while (0)

int main() {
  if (cpu_only_value() != 123)
    return 4;
  int value = 10;
  int *device;
  CHECK(cudaMalloc(&device, sizeof(value)));
  CHECK(cudaMemcpy(device, &value, sizeof(value), cudaMemcpyHostToDevice));
  launch_a(device);
  CHECK(cudaGetLastError());
  CHECK(cudaDeviceSynchronize());
  CHECK(cudaMemcpy(&value, device, sizeof(value), cudaMemcpyDeviceToHost));
  if (value != 51)
    return 2;
  launch_b(device);
  CHECK(cudaGetLastError());
  CHECK(cudaDeviceSynchronize());
  CHECK(cudaMemcpy(&value, device, sizeof(value), cudaMemcpyDeviceToHost));
  CHECK(cudaFree(device));
  if (value != 92)
    return 3;
  std::puts("PASS: four kernels, two TU images; A=51, B=92");
}
