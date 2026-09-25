# LLVM CUDA compilation

This workspace uses `cuda_toolkit` 0.0.5 from the BCR, CUDA 13.1.1, and the LLVM
module from the repository checkout. Register the ordinary LLVM C++ toolchains
and the CUDA toolkit toolchains, as shown in [MODULE.bazel](MODULE.bazel).
There are no separate CUDA C++ toolchain registrations or bootstrap compilers.

## Compilation model

For a nonempty `srcs` list, `cuda_library` creates five private targets: device
compilation, fatbins, host compilation, redirected host objects, and payload
objects. The public `cc_library` owns the objects used in the final CPU link.
A split transition compiles each source for every requested SM, then packs its
cubins into a per-source fatbin.

Host compilation uses an empty fatbin and runs independently of device
compilation. The native C redirect tool changes only Clang's wrapper payload
relocation to a unique symbol. A separate assembly object defines that symbol
around the real image using `.incbin`. Clang's launchers, constructors and
registration remain intact. Neither host compilation nor redirection depends
on the real image, and each payload compilation consumes only its own fatbin.

An aspect maps direct compile outputs to their source inputs. Source owner labels
and relative paths identify TUs across SM configurations, including generated
files and filegroups. Missing or ambiguous mappings are rejected. This requires
Bazel to expose `CppCompile` action metadata; the rules do not guess object names.
For each TU, redirection selects the PIC object when available, otherwise non-PIC.
Exporting one variant avoids duplicate definitions under `alwayslink`.

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
- Every source must emit CUDA device registration (kernels or device globals).
  A source with only CPU code belongs in `cc_library`; CUDA-dependent headers
  can still use `--offload-host-only` and the CUDA toolkit path there. Missing
  wrappers are errors, never silently copied through. Header-only
  `cuda_library` targets remain supported.
- CUDA host objects must be native little-endian ELF64 relocatables with RELA
  relocations. The native tool supports x86-64 and AArch64 and rejects ambiguous
  symbols, unexpected wrapper metadata, RDC, bitcode and unsupported layouts.
- ThinLTO is disabled for CUDA host objects, as it is for device cubins. Other
  CPU code and the final link may use ThinLTO. Explicit `-flto` options that
  produce bitcode are rejected. Compiler, runtime and CPU FDO workload
  transitions clear CUDA device settings.

## Tests

From this directory:

```sh
bazel test --config=remote //...
bazel test --config=remote //... --features=thin_lto --experimental_output_paths=strip
bazel test --config=remote //:vector_cuda_test --extra_toolchains=@llvm_toolchains//:linux_x86_64_to_linux_x86_64
```

`vector_cuda_test` executes GPU code and needs a GPU compatible with one of its
SM images. `attributes_test` checks compilation attributes, exported defines,
host dependency linking and retention of an otherwise unreferenced constructor
through `alwayslink`. Analysis tests check feature forwarding, isolation from
CPU ThinLTO, and one direct cubin per requested SM in the fatbinary. Additional
analysis tests check empty-image host inputs, image-free redirection and absence
of raw host archives in the exported link context. `redirect_test` checks malformed
ELF inputs, section-symbol/named-symbol relocations and rejection of CPU-only
sources. `decoupled_test` and `decoupled_shared_test` execute four kernels from two
translation units with distinct images through static and shared library links.
`source_mapping_test` repeats that execution with duplicate basenames, generated
sources and a filegroup in reversed source/SM order. Payload analysis tests assert
that each embedding action consumes exactly one distinct image. `pic_mapping_test`
checks PIC selection and distinct per-TU symbols. Exercise linking with both
compile variants available using:

```sh
bazel test --config=remote -c opt --features=-prefer_pic_for_opt_binaries \
  //:source_mapping_test //:decoupled_shared_test //:attributes_test //:pic_mapping_test
```

AArch64 can be compiled and linked from an x86-64 host with:

```sh
bazel build --config=remote --platforms=@llvm//platforms:linux_aarch64 //:decoupled_test //:vector_cuda_test
```

This is a cross-compilation check; executing those tests requires an AArch64
machine with a compatible NVIDIA GPU and driver.

FlashAttention FA2 (56 sources, `sm_80` and `sm_120`) passed remote compilation,
shared-library linking and loading. Numerical execution was not tested.
[Validation invocation](https://app.buildbuddy.io/invocation/a938373c-70c5-44f0-81cf-b64d9d356610).

Bootstrap configuration can be checked without rebuilding LLVM:

```sh
bazel build --nobuild //:vector_cuda_test --@llvm//toolchain:bootstrap_stage=stage1_from_source
bazel build --nobuild //:vector_cuda_test --@llvm//toolchain:bootstrap_stage=stage2_lto_and_fdo_instrumented
bazel build --nobuild //:vector_cuda_test --@llvm//toolchain:bootstrap_stage=stage3_lto_and_fdo_applied
```

These analysis checks do not execute full compiler bootstrap builds.

To build the complete ThinLTO/FDO bootstrap and execute the runtime tests:

```sh
bazel --bazelrc=../../.bazelrc test --config=remote //:vector_cuda_test //:attributes_test --@llvm//toolchain:bootstrap_stage=stage3_lto_and_fdo_applied
```

Compilation runs remotely. Both runtime tests execute locally because their
binaries require the NVIDIA driver library, including the attributes test that
does not launch a kernel. The vector test additionally requires a compatible GPU.
