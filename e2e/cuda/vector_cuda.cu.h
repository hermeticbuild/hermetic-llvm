//
// Created by yuriit on 2/13/25.
//

#ifndef VECTOR_CUDA_H
#define VECTOR_CUDA_H

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

__global__ void VectorAdd(const int *a, const int *b, int *c, int n);
int VectorGenerateAndSum(int size);

#endif //VECTOR_CUDA_H
