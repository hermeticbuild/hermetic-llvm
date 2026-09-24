//
// Created by yuriit on 2/7/25.
//

#include "vector_cuda.cu.h"
#include <stdio.h>

__global__ void VectorAdd(const int *a, const int *b, int *c, int n) {
  int i = threadIdx.x;

  if(i < n) {
    c[i] += a[i] + b[i];
  }
}

int VectorGenerateAndSum(int size) {
  int *a, *b, *c;

  cudaMallocManaged(&a, sizeof(int) * size);
  cudaMallocManaged(&b, sizeof(int) * size);
  cudaMallocManaged(&c, sizeof(int) * size);

  for(int i = 1; i <= size; ++i) {
    a[i] = i;
    b[i] = i;
    c[i] = 0;
  }

  int sum = 0;
  VectorAdd<<<1, size>>>(a, b, c, size);
  cudaDeviceSynchronize();
  for(int i = 0; i < size; ++i) {
    printf("c[%d] = %d\n", i, c[i]);
    sum += c[i];
  }

  cudaFree(a);
  cudaFree(b);
  cudaFree(c);

  return sum;
}
