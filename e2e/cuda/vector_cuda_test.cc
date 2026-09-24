//
// Created by yuriit on 2/13/25.
//

#include "vector_cuda.cu.h"
#include "gtest/gtest.h"

TEST(VectorCudaTest, VectorCudaTest) {
    EXPECT_EQ(90, VectorGenerateAndSum(10));
}
