#pragma once

#include <immintrin.h>

#include <string>

// Uses the intrinsics module from this library's header module.
inline int SumLanes(__m128i lanes) {
  alignas(16) int values[4];
  _mm_store_si128(reinterpret_cast<__m128i*>(values), lanes);
  return values[0] + values[1] + values[2] + values[3];
}

std::string Describe(int sum);
