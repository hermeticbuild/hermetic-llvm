# Bootstrap toolchain

This package holds the LLVM bootstrap binaries, FDO profile generation rules,
and both the `toolchain()` targets and `cc_toolchain` implementations for
source-built stages. The toolchain module extension declares both kinds of
targets in `@llvm_toolchains//bootstrap`.

The bootstrap stages are:

1. `stage0_prebuilt_seed` compiles the stage1 LLVM binaries from source.
2. `stage1_from_source` compiles the stage2 LLVM binaries with ThinLTO and FDO
   instrumentation where FDO is supported.
3. `stage2_lto_and_fdo_instrumented` runs the supported profile workloads.
   `stage1_from_source` compiles the stage3 LLVM binaries with ThinLTO and, on
   profile-compatible targets, the merged profile for the target CPU.
4. `stage3_lto_and_fdo_applied` is the historical name of the setting that uses
   stage3 LLVM binaries as the C++ toolchain. A Windows MSVC stage3 binary does
   not contain FDO despite that generic setting name.

## Stage production and selection

The stage being produced and the compiler selected to produce it are distinct:

| Output or work | Selected compiler | Purpose |
| --- | --- | --- |
| Stage 1 binaries | Downloaded Stage 0 compiler | Establish a compiler built from the current LLVM source. |
| Stage 2 binaries | Source-built Stage 1 compiler | Produce a ThinLTO compiler instrumented for host FDO. |
| FDO workloads | Instrumented Stage 2 compiler | Run compiler processes and collect the profile used for Stage 3. |
| Stage 3 binaries | Source-built Stage 1 compiler, plus the merged profile where supported | Produce the final ThinLTO compiler, with FDO on supported targets. |
| Normal final builds | Stage 3 compiler | Use the compiler that is packaged as the LLVM prebuilt. |

Stage 2 therefore generates profile data; it does not compile Stage 3. The
bootstrap transition in `bootstrap_binary.bzl` selects Stage 0 for Stage 1 and
Stage 1 for both the instrumented Stage 2 and source-backed Stage 3 builds.
The `bootstrap_stage` build setting selects the matching source-built toolchain
registration declared by `declare_toolchains.bzl`.

Linux compiler binaries selected by the bootstrap toolchains target musl,
including Stage 2. Their explicit compiler platforms carry the musl constraint
so the bootstrap transition does not fall back to glibc. `--config=remote`
uses the host-architecture glibc execution platform. Pass `--config=release`
after `--config=remote`, as the release scripts do, to override it with the
x86_64 and aarch64 musl execution platforms.

Windows MSVC Stage 3 binaries use ThinLTO but do not use FDO. Profile generation
runs the instrumented compiler process, not the target program it emits. The
available profile executors are Linux binaries and therefore record Itanium C++
linkage names, which do not match the Microsoft C++ linkage names in a Windows
MSVC LLVM binary. Clang profile remapping does not support the Windows C++ ABI.
MSVC FDO must remain unsupported until training can execute an instrumented
Windows LLVM binary and demonstrate profile application to named C++ functions.

## Compiler resource headers

Clang resource headers belong to the compiler executable, not the target SDK:

- Downloaded Stage 0 tools and `lib/clang/<major>/include` come from the same
  installed archive. `//toolchain/llvm:llvm.bzl` declares that archive's Bazel
  interface.
- Each source-built stage materializes `@llvm-project//clang:builtin_headers_files`
  under its own stage prefix. Those headers correspond to the LLVM source used
  to build that compiler generation.
- Target headers, such as VC, UCRT, and the Windows SDK, remain separate target
  inputs. They must not replace or be confused with the exec compiler's Clang
  resource headers.

Downloaded and source-built toolchains both disable implicit driver insertion
and re-add the selected resource-header directory explicitly. This avoids
duplicate Clang search entries and lets clang-cl place the directory between
libc++ and the Microsoft target headers.

`//toolchain:selects.bzl` maps Stage 0 requests to downloaded toolchain
repositories and source-backed requests to the Stage 1/2/3 labels. Never pair a
downloaded compiler with resource headers from the newer source tree currently
being compiled.

`//toolchain/bootstrap/stage1:<tool>` builds the stage1 variant.
`//toolchain/bootstrap/stage2:<tool>` builds the stage2 variant.
`//toolchain/bootstrap/stage3:<tool>` builds the stage3 variant.
`//prebuilt/llvm:all` packages `//toolchain/bootstrap/stage3:llvm`.
