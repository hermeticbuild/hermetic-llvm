#ifdef __CUDA_ARCH__
#error "Host dependency objects must not be built or packed into a CUDA fatbinary"
#endif

int cuda_library_increment() { return 1; }
