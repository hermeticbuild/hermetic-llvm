// WASI support covers C only, so C++ sources must not find libc++ headers
// that the toolchain neither configures for WASI nor links.
#if __has_include(<vector>)
#error "libc++ headers must not be visible on WASI"
#endif

extern "C" int wasi_no_cxx_stdlib() { return 0; }
