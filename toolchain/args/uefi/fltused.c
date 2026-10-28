// This marker is emitted by MSVC-ABI-compatible compilers when an object uses
// floating-point registers. A hosted CRT normally provides it; freestanding
// UEFI binaries only need the symbol to exist.
int _fltused __attribute__((weak)) = 0;
