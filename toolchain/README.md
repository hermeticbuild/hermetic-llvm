# Toolchain definition

Toolchains are defined as a composition of canonical argument groups, each representing a stable semantic aspect of the toolchain:
- Linker choice.
- Sysroot.
- Resource directory.
- Default startfiles.
- Hermetic compile and link flags.
- Deterministic compile and link flags.
- Default compile and link flags.
- Default libs.
- Sanitizers.

Each group has a stable meaning across all platforms and targets, even if its concrete flags differ or the group is empty.

Groups are defined at the level of the most constrained targets, so that more feature-rich or hosted environments compose or extend existing groups rather than redefining their semantics. For example, default_libs may be empty for freestanding or embedded targets, while being non-empty for hosted environments.

### Package structure

**//toolchain:BUILD.bazel**:
- Owns complete rules_cc argument-list ordering and composition.
- Exposes the public `toolchain_args` target consumed by `cc_toolchain`.
- Selects between complete generic and Windows compositions at the target-OS
  boundary.
- References named semantic implementations; it contains no raw flags or
  action bindings.

`windows_toolchain_args` is intentionally a complete composition rather than a
late platform-specific delta. Its semantic slots may use generic
implementations unchanged or select Windows, clang-cl, COFF, MSVC ABI, CRT, and
SDK implementations as appropriate. This explicit duplication is temporary
while those semantics are normalized. `platform_specific_args` remains only as
a legacy holder for generic platform behavior that has not yet been decomposed;
it is not the Windows extension point.

**//toolchain/args:BUILD.bazel**:
- Defines generic argument implementations and reusable compiler-personality
  implementations.
- Groups may be empty, but their semantic meaning must remain stable.
- Does not own complete toolchain ordering.

This package provides generic and personality-specific semantic pieces for the
top-level compositions.

**//toolchain/args/\<platform\>:BUILD.bazel**:
- Defines named semantic overrides for one target OS/platform family.
- May select peer implementations at the next platform-local level—such as a
  Windows target ABI/environment or an intentional empty implementation.
- Does not define the complete rules_cc argument list or its ordering.

For example, `//toolchain/args/windows:unwindlib` selects the applicable
Windows implementation of that one semantic. `//toolchain:windows_toolchain_args`
composes it in the complete Windows toolchain.

**//toolchain/args/\<platform\>/\<variant\>:BUILD.bazel**:
- Defines semantic implementations scoped to one selected platform variant.
- May select dimensions that further specialize that scope, such as CRT
  family or linkage, CPU, SDK version, or runtime build stage.
- Owns the concrete flags, action bindings, inputs, and data for that scoped
  implementation.

Selection follows the package hierarchy: a package may refine dimensions below
its declared scope, but it must not route upward to a broader target OS or
sideways between peer variants. For example, `//toolchain/args/windows` selects
MinGW versus MSVC implementations, while the selected variant may refine its
own CRT choice. Compiler personality and execution platform remain separate
axes rather than deeper platform variants.

Compiler personality is a separate axis from target OS, object format, ABI,
CRT, SDK/runtime family, C++ runtime, and execution platform. Reusable clang-cl
grammar stays in compiler-personality argument and feature layers. A supported
Windows composition explicitly combines that grammar with its COFF and MSVC
target semantics.

**//toolchain/runtimes:BUILD.bazel** follows the same ownership rule for staged
runtime toolchains: its public `toolchain_args` selects complete generic or
Windows runtime compositions, while concrete runtime compiler/linker semantics
remain in argument implementation packages.

### WASI semantic routing

`//constraints/wasi:variant` selects the coherent WASI profile: `p1` (the
default), `p1_threads`, `p2`, or `p3`. The setting covers both API generation
and the threaded P1 profile; it is not an independent threading setting.

The complete composition selects `//toolchain:linker` by target OS. WASI then
selects ordinary LLD or `//toolchain/args/wasi/components:linker`; the generic
argument package does not select WASI variants. Staged runtime compositions
retain their own `linker` slot using LLD for intermediate links.

`wasi_hosted_c_toolchain_args` composes WASI's
`libc_headers_include_search_paths` implementation for complete applications and
`stage1_hosted`, following the existing platform-specific hosted-C composition.
There is no WASI-only global libc-header slot. Stage 0 builds wasi-libc with its
own explicit header dependencies; it does not obtain them from the hosted group.
Public WASI libc headers use Clang's internal system include category, after
user system paths and compiler resource headers, before user `-idirafter`
paths. This preserves compiler wrappers such as `limits.h` and their
`include_next` lookup into libc. Explicit libc paths retain the existing
behavior under `-nostdinc` and `-nostdlibinc`; those flags do not suppress them.

`default_startfiles` owns CRT lookup and `default_libs` owns library lookup.
WASI uses the shared `crt_search_directory` implementation and
`//runtimes:crt_objects_directory` selection for its separate CRT directory.
The library search directory contains archives only. Clang still selects the
command or reactor startup object; CRT generation and component metadata remain
owned by wasi-libc's build.

The staged composition consumes `//toolchain:thread_model` and
`//toolchain:target_features`. These select WASI profile implementations and are
empty for other target OSes. Pthread mode and local-exec TLS remain part of the
WASI thread-model implementation; `-matomics` belongs to target features.
Complete applications retain their driver-selected behavior without these
explicit runtime flags. Libc source-language requirements such as `-fdefer-ts`
and their compiler-version restrictions belong to the libc build.

The `components` package is a shared implementation for P2/P3, not another
selectable ABI. Its linker tool map is selected in the target configuration,
before the execution transition. The map binds `wasm-component-ld` to the same
explicit execution OS/CPU as Clang and `wasm-ld`, for prebuilt and source-built
toolchains. The selected link tool declares both executables and supplies
`COMPILER_PATH`; the semantic argument group supplies `-fuse-ld=ld`. P1 and
non-WASI tool maps do not acquire the component linker. `wasm-tools` remains
execution-toolchain resolved for the separate CRT metadata action.
Other platforms retain their existing compositions while their remaining
legacy semantic groups are normalized separately.

TODO(cerisier): Support macOS specific flags (objc and frameworks). Still needed ?

# Other Resources

https://github.com/bazelbuild/rules_cc/blob/main/docs/toolchain_api.md
https://github.com/CACI-International/cpp-toolchain/blob/74efb5bc636f48db86652f0cfdb7d46af100e51f/bazel/toolchain.bzl#L31
https://github.com/cortecs-lang/cortecs-cc-toolchain/blob/78792fba9eec75bfac14a0cd20cb0e4973175871/sysroot/alpine/BUILD
https://github.com/lukasoyen/bazel_linux_packages/blob/c50a9bf22122a507d2bb5e348231413a05e6d90f/e2e/toolchains/gcc/BUILD.bazel
https://github.com/lowRISC/opentitan/blob/6d29bb86581892c43d3dea8856b275dc3a40c575/toolchain/README.md
https://cs.opensource.google/pigweed/pigweed/+/main:pw_toolchain/cc/args/BUILD.bazel
https://github.com/envoyproxy/envoy/blob/main/bazel/rbe/toolchains/configs/linux/clang/cc/cc_toolchain_config.bzl
