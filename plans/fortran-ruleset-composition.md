# Future Fortran ruleset and Hermetic LLVM composition

Status: design record, 2026-11-16. No Fortran ruleset, Flang retrieval API,
runtime target, intrinsic-module target, Hermetic LLVM Flang toolchain provider,
CC feature, or build setting is implemented or approved here. The separate
minimal-prebuilt review branch is `cerisier/flang-minimal-prebuilts`; no release
has been published.

## Decisions so far

- The first Flang release is for this repository's current LLVM source pin,
  **23.1.2**. LLVM 21/22 Flang releases need Bazel overlay backports and are
  deferred; LLVM 23.1.5 waits for the repository's ordinary LLVM update.
- Match the eight LLVM prebuilt **execution** platforms. Each Flang archive
  contains only `bin/flang` or `bin/flang.exe` and Flang/LLVM licenses. The
  compiler is stripped and built with ThinLTO, without Flang FDO. It contains
  no target intrinsic modules, Flang-RT, libc headers or libraries, CRT,
  sysroot, linker, Clang, or target-specific configuration file.
- The planned asset name is
  `flang-toolchain-23.1.2-<host suffix>.tar.zst`, published by a dedicated
  `flang-23.1.2-r<revision>` release branch with SHA256 and attestation, like
  the LLVM prebuilt workflow. No release is authorized before review and merge.
- A future Fortran ruleset owns its generic Fortran toolchain type/provider and
  the build rules. Hermetic LLVM does not own a Flang toolchain provider. Its
  existing CC toolchain is the preferred final-link owner.
- No global Flang mode or automatic addition of Flang-RT to all CC links is
  justified. Flang-RT is a language dependency of a Fortran library or
  executable, so its linking context must propagate with that dependency.
- The exact downstream labels, provider fields, retrieval extension, and any
  language-neutral LLVM target-triple API remain separate public API decisions.

The Flang prebuilt branch built all eight LLVM 23.1.2 host archives with the
existing `--config=remote --config=release //prebuilt/flang:all` pattern. All
eight tar listings contain exactly the compiler and two licenses. Linux
x86_64-musl's binary is stripped and statically linked. A small LLVM 23 source
patch fixes a Windows GNU ThinLTO link failure; the failing ARM64 GNU build
passed after the patch. This qualifies packaging, not a production Fortran
consumer or runtime on eight target platforms. The GitHub `release`
environment must allow `flang-*` branches before the first release branch is
pushed. Publication waits for approval and merge.

## What compiler agnostic means

Fortran defines source-language semantics, not one official compiler or a
standard driver command line. Flang and GNU Fortran can compile standard
Fortran, but supported extensions, incomplete features, diagnostics, and flags
differ. Flang uses Clang's driver infrastructure. Its `--target=<LLVM triple>`
chooses code generation; a GNU cross compiler is normally a separate
target-configured executable. Neither spelling belongs in the common rule.

The common rules can own declared source/include inputs, dependency scanning,
module ordering, compile actions, object/PIC handling, libraries, executables,
tests, and propagation of native linking information. A compiler adapter owns
the executable and runfiles, flag syntax, target selection, intrinsic-module
strategy, runtime dependency, and supported capabilities. Start with Flang;
another adapter may be added only with its own qualified, hermetic compiler and
target runtime. Host-installed compilers or target libraries are not an
acceptable fallback.

`.mod` files are compiler-specific compile artifacts. They must be generated
and consumed with the selected compiler and target configuration; do not share
Flang `.mod` files with GNU Fortran. `BIND(C)` is the explicit interoperability
boundary for mixed-compiler libraries; arbitrary Fortran object/module ABI
compatibility is not assumed.

The generic toolchain shape below is **illustrative**, not a proposed public
provider contract:

```starlark
# Defined by the future Fortran ruleset, not by Hermetic LLVM.
FortranToolchainInfo(
    compiler = <execution-configured executable and files>,
    compile_adapter = <compiler-specific argument construction>,
    intrinsic_modules = <target-configured declared inputs>,
    runtime = <target-configured CcInfo>,
    capabilities = <qualified features>,
)
```

Do not put a fixed `target_triple` string in this generic provider. Bazel's
selected target platform and CC toolchain determine the target. A Flang adapter
derives the matching LLVM triple and ABI/CPU options from target constraints at
analysis time. The current internal Hermetic LLVM mapping is
`toolchain/args/llvm_target_triple.bzl`; a shared public, language-neutral
building block is plausible, but its label and contract require explicit
approval. Do not use deprecated `CcToolchainInfo.target_gnu_system_name` as
the source of the LLVM target. A GNU Fortran adapter may select a target-fixed
compiler instead of passing a triple. Compare actual Fortran and CC action
arguments for each qualified target, including libc and Windows ABI/CRT.

## Compile and link ownership

1. The adapter selects an execution-platform compiler. Flang compiles ordinary
   CPU Fortran to an object with integrated frontend/code generation; `-c`
   does not need a target libc, linker, or Flang-RT archive as an action input.
   Fortran source normally needs no C libc headers. C interoperability code
   may need the target `ISO_Fortran_binding.h` as a declared header input.
2. The ruleset declares user module dependencies and output directories. A
   Flang adapter supplies matching target intrinsic `.mod` files, generated
   from the same LLVM source/version with the target flags. They are compile
   inputs, never final-link inputs.
3. The ruleset passes Fortran objects plus native and runtime linking contexts
   to `cc_common.link`. Fortran libraries propagate their own linking context
   and the runtime `CcInfo`, so a downstream C/C++ main also receives Flang-RT.
   The Fortran rule must handle real PIC/non-PIC outputs and link ordering.
4. The selected Hermetic LLVM CC toolchain performs the link with its configured
   Clang/LLD action, startup objects, libc/sysroot or SDK, compiler builtins,
   and other configured C++/unwind runtimes. `cc_common.link` contributes no
   Fortran runtime by itself. The Fortran side supplies Flang-RT and any
   qualified Fortran-specific math, quadmath, OpenMP, or other libraries.

Illustrative rule flow, not an approved provider or target API:

```starlark
# The compiler adapter made `fortran_objects` (CcCompilationOutputs with real
# objects and pic_objects) in separate compile actions.
# `native_deps` and `runtime` are target-configured CcInfo values.
cc_common.link(
    actions = ctx.actions,
    cc_toolchain = selected_cc_toolchain,
    feature_configuration = selected_cc_features,
    compilation_outputs = fortran_objects,
    linking_contexts = [dep.linking_context for dep in native_deps] +
                       [runtime.linking_context],
    name = ctx.label.name,
)

# A Fortran library must also return CcInfo that propagates its objects and
# runtime linking context to downstream cc_binary and Fortran consumers.
```

The selected CC toolchain contributes only what its normal configuration
would contribute to a C/C++ link. The Fortran rule does not extract and replay
Clang's raw linker flags, and the runtime is not installed in a CC resource
directory or global `static_runtime_lib` merely to make it implicit.

LLVM 23.1.2 Flang lowering emits a normal C `main` for a Fortran main program;
the scratch Linux x86_64-musl probe linked it through `cc_common.link` with a
source-built target Flang-RT `CcInfo`. Omitting that runtime produced undefined
`_Fortran*` symbols. This is evidence for one static target pair, not proof of
production integration, shared links, or other platforms. See
[flang-prebuilt.md](flang-prebuilt.md) for the action and artifact evidence.

Flang can also act as a **link driver**: it invokes an external linker and
normally adds Flang-RT. This is a possible second backend for a future ruleset,
including a complete hermetic Fortran toolchain from another source. The
minimal Flang archive alone cannot drive a hermetic link: that action must
declare the target linker, CRT, sysroot/SDK, builtins, Flang-RT, libc/math
libraries, search paths, and correct ordering. Flang's `--ld-path` selects a
raw linker, not a Clang driver, so pointing it at Clang does not transfer the
Hermetic LLVM CC toolchain's cross environment. Do not support a host-installed
fallback. The initial Hermetic LLVM composition should use `cc_common.link`.

## Next implementation boundary

After the minimal release is reviewed, merged, and explicitly published,
design the consumer API separately. Keep the Fortran ruleset's generic
toolchain provider independent of Hermetic LLVM; decide the smallest approved
way to retrieve exact-version host Flang and target modules/runtime. Qualify
the first Linux x86_64-musl static pair using the actual release archive and
matching source-built components. Inspect compile and link action inputs,
target arguments, `.mod` outputs, runtime propagation through a C-main
consumer, linked binary, and failure without Flang-RT. Add other targets and
link modes only after their declared closure works.

Primary references: [Flang driver and linker behavior](https://flang.llvm.org/docs/FlangDriver.html),
[Flang command line](https://flang.llvm.org/docs/FlangCommandLineReference.html),
[Flang module files](https://flang.llvm.org/docs/ModFiles.html),
[Flang language coverage](https://flang.llvm.org/docs/FortranStandardsSupport.html),
[GCC target configuration](https://gcc.gnu.org/install/configure.html).
