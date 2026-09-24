//
// Created by yuriit on 2/13/25.
//

#include <iostream>
#include "vector_cuda.cu.h"

using namespace std;

int main() {
    printf("Sum: %d\n", VectorGenerateAndSum(10));
    return 0;
}
