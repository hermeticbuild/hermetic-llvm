# Proposed Flang integration contract (for approval)

**Superseded:** Corentin rejected Hermetic LLVM ownership of the Flang
toolchain type/provider and chose a compiler-agnostic future Fortran ruleset.
Current decisions: [fortran-ruleset-composition.md](fortran-ruleset-composition.md).
This document records the earlier proposal only; none of its labels, provider
fields or target counts are approved.

Status: historical proposal only. Toolchain ownership is now assigned to the
future compiler-agnostic Fortran ruleset. No public API or implementation is
authorized by this document. The earlier qualified pair was Linux x86_64
execution and Linux x86_64 musl target, static executable.

## Superseded proposal (retained as design history)

### Toolchain ownership options at the time

| Option | Downstream contract | Public surface now | Cost |
|---|---|---|---|
| A. Hermetic LLVM Flang companion toolchain (recommended) | A Fortran rule resolves a Flang-specific toolchain and the existing C++ toolchain. Flang provides compilation inputs; `cc_common.link` uses the C++ toolchain. | Flang extension, one toolchain type, one ordinary runtime `CcInfo` target, and generated registrations. | Couples the LLVM integration path of a future ruleset to Hermetic LLVM's Flang type. A ruleset supporting multiple Fortran compilers can add an adapter later. |
| B. Ruleset-owned generic Fortran toolchain | Hermetic LLVM exports one target-configured Flang kit containing an execution-configured compiler, intrinsic modules and runtime. A future ruleset supplies its generic Fortran toolchain type and adapter; downstream users register the adapter. | Flang retrieval, one kit provider/label, and one ordinary runtime `CcInfo` target. The generic type cannot be defined here without choosing that future ruleset's API. | No automatic Fortran toolchain registration until the ruleset exists. The adapter selects the correct kit for the target platform and preserves version alignment. |
| C. Flang feature on the C++ toolchain | A Fortran rule asks the C++ toolchain for Flang link flags. Compiler and modules still need a separate retrieval mechanism. | C++ feature/build-setting surface plus compiler/module components and runtime metadata. | Does not solve compiler selection. A C++ binary depending on a Fortran library still needs the library's runtime `CcInfo`; link features alone cannot express that dependency. |

Option A is the smallest complete contract that can be probed before a Fortran ruleset exists. It does not claim to be a universal `fortran_toolchain`. The rest of this document spells out A for review; choosing B would replace its type and registration API with a kit target and defer the generic adapter design.

## Invariant

The Flang release contains host compiler files only. Hermetic LLVM owns target intrinsic modules, Flang-RT, C interoperability headers, and the selected C++ toolchain's CRT, libc, builtins, SDK and linker. A Fortran rule invokes Flang for compilation and `cc_common.link` for final linking. Flang and target sources must be from one qualified LLVM version/source identity; no bootstrap-seed version fallback. The previously approved artifact/tag form remains `flang-toolchain-<LLVM version>-<host suffix>.tar.zst` on manually published `flang-<LLVM version>-r<revision>` tags; despite the historical artifact name, it is a host compiler archive, not a standalone cross toolchain.

## Downstream Bzlmod entry point

Proposed new public extension `@llvm//extensions:flang.bzl`, symbol `flang`. Using it is the opt-in. V1 has **no tag classes**. It reads the LLVM version chosen by the existing `llvm.version(...)` mechanism, resolves only exact-version Flang release records, and generates repository `flang_toolchains`. No new build setting.

```starlark
bazel_dep(name = "llvm", version = "<approved release>")

llvm = use_extension("@llvm//extensions:llvm.bzl", "llvm")
llvm.version(llvm_version = "<matching LLVM source version>")
use_repo(llvm, "llvm-project")

# Existing Hermetic LLVM CC registration, unchanged.
llvm_toolchains = use_extension("@llvm//extensions:toolchain.bzl", "toolchain")
use_repo(llvm_toolchains, "llvm_toolchains")
register_toolchains("@llvm_toolchains//:all")

flang = use_extension("@llvm//extensions:flang.bzl", "flang")
use_repo(flang, "flang_toolchains")
register_toolchains("@flang_toolchains//:all")
```

For subset registration, the first concrete label is `@flang_toolchains//:linux_amd64_to_linux_amd64_musl`. `:all` is Bazel's package target pattern, not a separate rule. Future pairs require their own qualification; they are not implied by this API.

The extension may generate private host archive repositories. Their names and labels are not supported downstream API. The repository `flang_toolchains` and its registration labels are supported API. Its root package contains only registration targets; implementation and module-generation targets live in a private subpackage, so `:all` selects only toolchains. Missing exact-version release, unsupported host/target pair, or an unqualified source override must fail clearly. The existing LLVM minimal compiler fallback to a different bootstrap seed must not apply to Flang. V1 supports only the indexed LLVM source archive; the source extension must expose internal origin metadata so `from_path`, `from_git` and custom `from_archive` overrides can be rejected when this toolchain is used. A matching source-built compiler override would be a later public API.

## Public labels and providers

| Public surface | Location | Contract |
|---|---|---|
| `@llvm//toolchain/flang:toolchain_type` | `toolchain/flang/BUILD.bazel` | Companion Bazel toolchain type. Rules resolve it alongside the existing CC toolchain type. |
| Flang toolchain fields | `@llvm//toolchain/flang:toolchain_type` | Standard Bazel `ToolchainInfo` fields below; no new custom provider. |
| `@llvm//runtimes/flang:runtime` | `runtimes/flang/BUILD.bazel` | Target-configured ordinary `CcInfo` library, built from matching Flang-RT sources. Exposes `ISO_Fortran_binding.h` in its compilation context and any needed target libraries in its linking context. A Fortran library propagates this `CcInfo`. |
| `@flang_toolchains//:linux_amd64_to_linux_amd64_musl` | generated repository | V1 registered toolchain, Linux x86_64 exec to Linux x86_64 musl target. `@flang_toolchains//:all` registers all qualified pairs. |

Flang `ToolchainInfo` fields (all public, no other public fields in V1):

| Field | Type | Meaning |
|---|---|---|
| `compiler` | `FilesToRunProvider` | Execution-configured `bin/flang`, with all host execution files declared. |
| `llvm_version` | string | Qualified compiler/source version used by both modules and runtime. |
| `target_triple` | string | Normalized target triple selected from Hermetic LLVM's target configuration. |
| `compile_flags` | list of strings | Flang frontend flags required for the target ABI/CPU, beginning with the target triple. Does not include per-rule optimization, debug or PIC choices. |
| `intrinsic_modules` | depset of `File` | Target `.mod` outputs generated from the matching LLVM source using `compiler`. |
| `intrinsic_module_dir` | string | Declared directory passed as `-fintrinsic-modules-path`. |
| `runtime` | `CcInfo` | Same target runtime as `@llvm//runtimes/flang:runtime`. Its compilation context includes the C descriptor header. |

The public toolchain type lets Bazel's toolchain transition keep the `cfg = "exec"` compiler aligned with the consuming rule's execution platform while runtime and modules stay in the target configuration. Target-specific Flang options reuse Hermetic LLVM's existing triple/ABI selections; no parallel target table or raw Clang flag forwarding.

## Build settings and selection

New public build settings: **zero**. Existing `--platforms`, libc/ABI/CRT constraints, Hermetic LLVM CC toolchain registration and CC link features remain authoritative. The Flang extension is the opt-in; there is no global `--flang` or `flang_runtime` switch and no change to all C/C++ links. V1 does not promise dynamic, shared, OpenMP, quadmath, CUDA or Windows linking. The probe requests a fully static Linux link; future modes require independent qualification. `--@llvm//toolchain:bootstrap_stage` continues to choose the CC bootstrap stage and does not select a mismatched Flang compiler.

## Placement and initial target count

| Package | Purpose | V1 count |
|---|---|---:|
| `prebuilt/flang/` | Minimal archive rule and release workflow inputs; `bin/flang`, licenses, provenance only. | 1 qualified host archive |
| `extensions/` | Exact-version Flang prebuilt index and opt-in extension. | 1 generated toolchain repository + 1 private host archive repository |
| `toolchain/flang/` | Toolchain type and implementation rule. | 1 public type, 1 implementation instance for the qualified pair |
| `runtimes/flang/` | Target Flang-RT `CcInfo`, interop header and intrinsic-module generator rule definition. | 1 public runtime target |
| Generated `@flang_toolchains` | Pair-specific `native.toolchain` registrations at repository root; private implementation and target-module instance in a subpackage. | 1 public registration target, 1 private module target |
| `e2e/flang/` | Private probe rule and test targets. | No public API |

The selected LLVM source archive's Flang/Flang-RT trees become available for target builds; no second source archive or libc payload is added to the host release. This adds roughly 52 MB of extracted source when `@llvm-project` is materialized, based on the 23.1.2 scratch tree; build actions remain lazy.

## Future Fortran ruleset contract

The ruleset declares both `@llvm//toolchain/flang:toolchain_type` and the existing CC toolchain type. It obtains `ctx.toolchains["@llvm//toolchain/flang:toolchain_type"]` and the selected CC toolchain. It owns source/module dependency graph, fixed/free-form preprocessing, user module outputs, compile modes, PIC objects, libraries, binaries and tests.

For compilation, it invokes `compiler` with `compile_flags`, explicit intrinsic/user `.mod` inputs and `-fintrinsic-modules-path`; only declared source/header/module/tool files enter the action. For a library, it returns its own objects/archive and the Flang runtime's `CcInfo` so a C/C++ main inherits the runtime. For an executable, it passes objects and all native/runtime linking contexts to `cc_common.link` with the selected CC toolchain. It does not call Flang as the linker or reconstruct Hermetic LLVM's CRT/sysroot flags.

The ruleset may support other Fortran compilers through other toolchain types/adapters. Hermetic LLVM does not implement general Fortran build rules in V1.

## Private probe and acceptance before release

The bespoke probe rule mimics the two critical paths: (1) a Fortran main importing intrinsic and user modules, compiled with Flang and linked with `cc_common.link`; (2) a C main depending on a Fortran library whose `CcInfo` propagates Flang-RT. It uses the actual newly built minimal archive, source-generated target modules and source-built target runtime. Inspect action inputs and link command, confirm compiler and source version, CRT/libc/builtins selection, runtime ordering, executable format and runtime output. A missing intrinsic module must fail compilation; a missing Flang-RT must fail linking. The earlier scratch probe proves this architecture for one pair but not the production package/API.

Publication remains manual, after approval and merge. No release, toolchain registration or new downstream API is created by this proposal.

## Decision requested

Choose A, B, or a revised contract before implementation. Once agreed, implementation can replace the current bundled draft and add the private probe without inventing further public settings or labels.
