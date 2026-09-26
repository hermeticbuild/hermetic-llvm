# CUDA compilation policy

This package supplies CUDA device arguments and features to the ordinary LLVM
C++ toolchains. [cc_toolchain.bzl](../cc_toolchain.bzl) selects this policy when
`//config:cuda_device_mode` is enabled. Compiler selection, tool maps and resource
directories are shared with CPU compilation, including all LLVM bootstrap stages.
There are no separate CUDA C++ toolchain registrations or bootstrap compilers.

## Split compilation

[`cuda_library`](../../cuda.bzl) uses a split transition to set device mode and
`//config:nvidia_compute_capability` separately for each requested SM. For each
source, it creates:

1. One device compilation per SM, producing a cubin.
2. A fatbinary action packing that source's cubins across SMs.
3. A host compilation embedding the fatbinary.

The public C++ library aggregates the resulting host libraries. Only the source's
own device objects enter its fatbinary; transitive dependency objects do not.
This keeps device compilation independently schedulable and cacheable for each
source/SM pair. `srcs` must be non-empty; use `cc_library` for header-only libraries.

## Host ABI and device policy

Although device code targets NVIDIA GPUs, Clang still parses CUDA using the host
target's C++ ABI. The host triple, type layouts, libc headers and C++ standard
library headers must agree with the host compilation. The CUDA toolkit does not
provide that complete host environment.

[BUILD.bazel](BUILD.bazel) therefore reuses the common LLVM compile arguments and
host header configuration, while selecting CUDA device flags and features.
Device compilation supports Linux GNU targets on x86_64 and aarch64; other target
ABIs are explicitly incompatible. CPU ThinLTO and linking policy do not apply to
device cubins. Compiler bootstrap, runtime and CPU FDO workload transitions clear
the CUDA device settings so those dependencies continue to build for the CPU.

Device code must be self-contained in each translation unit: relocatable device
code and device linking are not supported. Fatbinaries contain SASS images for
the requested SMs, with no PTX fallback. The selected Clang and toolkit must
support those architectures.

## CUDA toolkit components

The CUDA toolkit has its own toolchain type,
`@cuda_toolchain_types//cuda:toolchain_type`. Register it alongside the ordinary
LLVM C++ toolchains. This package exposes two components from the selected toolkit:

- `current_cuda_path`: the toolkit tree passed to Clang through `--cuda-path`,
  including headers, libdevice and `bin/ptxas`. Clang invokes `ptxas` as part of
  device compilation.
- `current_fatbinary`: the executable used by the separate fatbinary action.

See the [CUDA example](../../e2e/cuda/README.md) for module registration, usage,
dependency semantics and tests, including source-built LLVM bootstrap validation.
