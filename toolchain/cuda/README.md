# CUDA aware CC toolchain

This package defines the Bazel cc_toolchain used when CUDA compilation is enabled.

It is intentionally separate from the regular CPU toolchains defined in this repository.
CUDA compilation has a different structure than normal C/C++ compilation and therefore requires a different set of compiler flags and configuration.

Why a separate toolchain

CUDA compilation is fundamentally a heterogeneous compilation model. A single .cu translation unit can contain either or both:
- host code, compiled for the CPU
- device code, compiled for the GPU (PTX / SASS)

During the device compilation pass, the compiler must still interpret the program in the context of a host C++ ABI.

Because of that, CUDA compilation still depends on a complete host C++ environment:
1. a host target triple
2. matching libc headers
3. matching C++ standard library headers (libc++ in this repository)

The CUDA toolkit itself does not provide a C or C++ standard library implementation; it relies on the host toolchain for these components.

For this reason this package still defines toolchains with CPU target compatibility for compatible CUDA target platforms (linux/windows x86/arm64).

Even though the final device code is compiled for nvptx, the compiler must parse the program using the host platform ABI. This means that:
- type sizes
- ABI layout rules
- libc and C++ headers

must match the host target.

Providing host-specific toolchains ensures that CUDA compilation uses the correct header sets and ABI configuration for the target platform.
