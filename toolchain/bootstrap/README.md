# Bootstrap toolchain

This package holds the LLVM bootstrap binaries, FDO profile generation rules,
and source-built C++ toolchains. The bootstrap stages are:

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

Windows MSVC Stage 3 binaries use ThinLTO, and FDO only with a profile trained
on Windows. Profile generation runs the instrumented compiler process, not the
target program it emits. The profiles of the Linux executors record Itanium C++
linkage names, which do not match the Microsoft C++ linkage names in a Windows
MSVC LLVM binary, and Clang profile remapping does not support the Windows C++
ABI. A profile trained by an instrumented MSVC-ABI LLVM binary on Windows applies
with `--//toolchain/bootstrap:use_external_fdo_profile`, see below.

## FDO training workloads

LLVM prebuilts cross-compile to every supported target, so each training
executor runs every target through the instrumented Stage 2 compiler.
`_LLVM_FDO_EXECUTORS` in `stage3/BUILD.bazel` lists the executors; each one
produces its own profile, `llvm_fdo_profdata_<executor>`. The Linux executors
are BuildBuddy workers. The macOS and Windows executors are the host running the
build, and their targets are manual: they train with
`--//toolchain/bootstrap:fdo_training_compiler=prebuilt`, which runs the host's
Stage 0 prebuilt, replaced by an instrumented Stage 2 archive through
`--override_repository`.

`llvm_fdo_profile_workload` in `fdo_profile.bzl` compiles for one target
platform. Hosted targets run these passes:

| Pass | Input | Flags | Trains |
| --- | --- | --- | --- |
| `lto` | zstd compressor (C) | `-O3 -flto=thin`, ThinLTO link | Frontend and IR optimizer; ThinLTO backend, codegen and linker |
| `debug` | zstd compressor (C) | `-O0 -g`, link with debug info | `-O0` codegen, debug info emission, linker debug info: CodeView and a PDB on Windows, a dSYM from `dsymutil` on macOS |
| `cxx_O2` | LLVM `Support` (C++) | `-O2` | C++ frontend, templates, optimized codegen |
| `cxx_O0_g` | LLVM `Support` (C++) | `-O0 -g` | C++ debug builds |

Freestanding targets (BPF, wasm) compile a small C function at `-O3`, and at
`-O2 -g`, the flags BPF programs use to emit BTF.

`Support` is also what LLVM's own `clang/utils/perf-training` builds. Its
sources, include paths and defines come from the `@llvm-project//llvm:Support`
target configured for the workload's target platform.

MSVC-ABI targets use clang-cl flags (`/O2`, `/Od /Z7`, `/DEBUG /PDB:`). On the
Windows executor they train the MSVC-ABI LLVM binary itself; in the other
profiles they cover MSVC-target code paths such as the Microsoft C++ ABI,
CodeView and PDB output.

Workloads keep the release configuration's `thin_lto`, `no_exceptions` and
`no_rtti` features out of their commands: each pass chooses its own LTO mode,
and C++ input keeps exceptions and RTTI like typical user code.

Each training pass is one action, like LLVM's `perf-training`: it runs the
pass's compiles in parallel, then its link. Every instrumented process (the
driver, lld, and `dsymutil` for macOS debug links) merges online into a pool of
raw profiles (`LLVM_PROFILE_FILE=<dir>/%8m.profraw`), and the action outputs
only the pass's sparse indexed profile. The C++ passes run in chunks of about
24 sources, one action each: 206 training units per executor.
`llvm_fdo_profile_data` merges the profiles of the units.

`--//toolchain/bootstrap:fdo_training_shard=<index>/<count>` makes
`llvm_fdo_profile_data` merge, and so build, only the units of one shard, chosen
by a hash of their names. The workloads keep one configuration across shards,
so the shards share their runtimes in the remote cache.
`--//toolchain/bootstrap:use_external_fdo_profile` builds Stage 3, including
MSVC-ABI binaries, with the profiles placed in
`//toolchain/bootstrap/external_fdo_profile`, merged.

### Training on other hosts

`.github/workflows/llvm-prebuilt-pgo.yml` trains on a host of the prebuilt's
own platform, so macOS and Windows prebuilts get a profile of themselves rather
than of the Linux binaries:

1. On Linux with BuildBuddy, `//prebuilt/llvm:instrumented_stage2_<host>`
   packages the instrumented Stage 2 for the host. Stage 2 is instrumented only
   in an exec configuration, so it is built with the host's platform appended to
   `--extra_execution_platforms`.
2. On a runner of the host, the archive replaces the host's Stage 0 repository
   (`--override_repository`), and `llvm_fdo_profdata_<executor>` is built with
   `--//toolchain/bootstrap:fdo_training_compiler=prebuilt`. The workloads run
   on the runner; the target runtimes they link build on BuildBuddy.
3. On Linux with BuildBuddy, the release archives are built with
   `--//toolchain/bootstrap:use_external_fdo_profile`, which applies the profile
   placed in `//toolchain/bootstrap/external_fdo_profile`.

Prebuilts train on their own host, or reuse a profile of the other
architecture of their OS: the training cross-compiles to every target on any
host, and the function names match across architectures.

| Prebuilt | Training host |
| --- | --- |
| Linux x86_64, arm64 | BuildBuddy workers of the architecture, within the Stage 3 build |
| macOS arm64 | `macos-15` runners, 4 shards |
| macOS x86_64 | reuses the macOS arm64 profile |
| Windows x86_64 (MSVC ABI) | `windows-2025` runners, 6 shards |
| Windows arm64 (MSVC ABI) | reuses the Windows x86_64 profile |

The training jobs of a host each train one shard, and Stage 3 merges the
profiles of all shards.

A final job collects every archive with its checksums.

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
