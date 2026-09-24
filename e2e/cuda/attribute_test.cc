#include "included.h"

#if CUDA_LIBRARY_DEFINE != 13
#error "cuda_library must export defines from its host libraries"
#endif
#ifdef CUDA_LIBRARY_LOCAL
#error "local_defines must not propagate to consumers"
#endif

int cuda_library_registrations = 0;
int main() { return cuda_library_registrations == 1 ? 0 : 1; }
