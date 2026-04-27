#include <cuda_runtime_api.h>
#include <cstdio>
#include <cmath>

extern "C" __device__ float __nv_erfcinvf(float);
__device__ float g_libdevice_probe;

#define CUDA_CHECK(call)                                                          \
    do {                                                                          \
        cudaError_t err__ = (call);                                               \
        if (err__ != cudaSuccess) {                                               \
            fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__,     \
                    cudaGetErrorString(err__));                                   \
            return 1;                                                             \
        }                                                                         \
    } while (0)

__global__ void saxpy(float a, float *x, float *y) {
    int i = threadIdx.x;
    g_libdevice_probe = __nv_erfcinvf(x[i] * 0.25f);
    y[i] = a * x[i] + y[i];
}

#ifndef __CUDA_ARCH__
int main() {
    const int N = 4;

    float hx[N] = {1, 2, 3, 4};
    float hy[N] = {10, 20, 30, 40};

    float *dx, *dy;

    CUDA_CHECK(cudaMalloc(&dx, N * sizeof(float)));
    CUDA_CHECK(cudaMalloc(&dy, N * sizeof(float)));

    CUDA_CHECK(cudaMemcpy(dx, hx, N * sizeof(float), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(dy, hy, N * sizeof(float), cudaMemcpyHostToDevice));

    saxpy<<<1, N>>>(2.0f, dx, dy);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    CUDA_CHECK(cudaMemcpy(hy, dy, N * sizeof(float), cudaMemcpyDeviceToHost));

    for (int i = 0; i < N; ++i)
        printf("%f\n", hy[i]);

    CUDA_CHECK(cudaFree(dx));
    CUDA_CHECK(cudaFree(dy));

    return 0;
}
#endif
