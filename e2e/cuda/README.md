# LLVM CUDA compilation

This workspace uses `cuda_toolkit` 0.0.5 from the BCR, CUDA 13.1.1, and the LLVM
module from the repository checkout. Register the ordinary LLVM C++ toolchains
and the CUDA toolkit toolchains, as shown in [MODULE.bazel](MODULE.bazel).
There are no separate CUDA C++ toolchain registrations or bootstrap compilers.

## Compilation model

For every source in `cuda_library`, a **split transition** creates one device
compilation configuration per entry in `archs`. Each configuration uses the
selected LLVM compiler with CUDA device compilation policy. The resulting
cubins are packed into a per-source fatbinary, which a separate host compilation
embeds. The public C++ library collects the host objects.

This preserves independent compilation actions, remote scheduling and caching
for every source/SM pair. Prebuilt and source-built LLVM stages use the same
compiler selection and resource-directory machinery as ordinary C++.

```starlark
load("@llvm//:cuda.bzl", "cuda_library")

cuda_library(
    name = "kernels",
    srcs = ["kernels.cu"],
    archs = ["sm_80", "sm_90", "sm_120"],
    deps = [
        "@cuda//cuda:cuda_headers",
        "@cuda//curand:headers",
        "@cuda//cccl:nv_headers",
    ],
    host_deps = ["@cuda//cudart"],
)
```

`deps` supplies compilation contexts to device code and ordinary dependencies
to host code. Transitive dependency objects are not packed into the fatbinary.
Use `host_deps` for dependencies needed only by the host pass.

Compile attributes such as `features`, `includes`, `local_defines`, and
`additional_compiler_inputs` reach both passes. `alwayslink` applies to the
libraries owning the host objects. Public defines, headers and dependencies
also propagate from header-only `cuda_library` targets. Unsupported keyword
attributes are rejected instead of being silently ignored.

## Supported scope

- Linux GNU host targets on x86_64 and aarch64; other target ABIs are explicitly
  incompatible with device compilation.
- Non-RDC compilation: device code must be self-contained in each translation
  unit. Device linking is not implemented.
- Explicit SASS images for the requested SMs; there is no PTX fallback image.
  Architectures must also be supported by the selected Clang and CUDA toolkit.
- CPU ThinLTO settings apply to host compilation, not device cubins. Compiler,
  runtime and CPU FDO workload transitions clear CUDA device settings.

## Tests

From this directory:

```sh
bazel test //...
bazel test //:vector_cuda_test //:attributes_test --features=thin_lto
bazel test //:vector_cuda_test --extra_toolchains=@llvm_toolchains//:linux_x86_64_to_linux_x86_64
```

`vector_cuda_test` executes GPU code and needs a GPU compatible with one of its
SM images. `attributes_test` checks compilation attributes, exported defines,
host dependency linking and retention of an otherwise unreferenced constructor
through `alwayslink`. Analysis tests check feature forwarding, isolation from
CPU ThinLTO, and one direct cubin per requested SM in the fatbinary.

Bootstrap configuration can be checked without rebuilding LLVM:

```sh
bazel build --nobuild //:vector_cuda_test --@llvm//toolchain:bootstrap_stage=stage1_from_source
bazel build --nobuild //:vector_cuda_test --@llvm//toolchain:bootstrap_stage=stage2_lto_and_fdo_instrumented
bazel build --nobuild //:vector_cuda_test --@llvm//toolchain:bootstrap_stage=stage3_lto_and_fdo_applied
```

These analysis checks do not execute full compiler bootstrap builds.
