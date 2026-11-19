// <windows.h> includes all intrinsics headers on x86_64 MinGW targets.
#ifdef _WIN32
#include <windows.h>
#endif

#include <emmintrin.h>

#include <string>

#include "intrinsics.h"

int main() {
  __m128i lanes = _mm_add_epi32(_mm_set1_epi32(1), _mm_setr_epi32(0, 1, 2, 3));
  return Describe(SumLanes(lanes)) == "sum: 10" ? 0 : 1;
}
