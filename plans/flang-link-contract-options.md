# Flang link integration choices (for discussion)

Status: proposal only. Corentin wants a future Fortran ruleset to own Flang toolchains and providers. No new Hermetic LLVM Flang toolchain type or provider. No public API, build setting, or release is approved by this document.

## Observed boundary

The Linux x86_64-musl scratch probe compiled Fortran with the minimal host Flang binary, generated target intrinsic modules from matching LLVM source, and linked the object with the current Hermetic LLVM CC toolchain through `cc_common.link`. The link succeeded when the action supplied the target Flang-RT `CcInfo` as a linking context. Omitting Flang-RT failed. The compiler did not need a bundled libc/sysroot or linker for the compile action. This proves a source-built target runtime can compose with the existing CC toolchain for one static executable; it does not prove a production archive or another platform/link mode.

Hermetic LLVM's CC toolchain already selects its CRT, libc, builtins, C++ runtime and linker from the target configuration. Its `static_runtime_lib`/`dynamic_runtime_lib` entries are toolchain-wide. The Flang-RT archive is a language dependency needed by Fortran programs, including a C/C++ main that depends on a Fortran library. A Fortran library must propagate that dependency through `CcInfo` regardless of any link mode chosen by its own rule.

## Options

| Option | Hermetic LLVM public API | Future ruleset behavior | Boundary |
|---|---|---|---|
| 1. Explicit target inputs, no CC switch (proven path) | Minimal host Flang archive retrieval; target intrinsic-module target; target Flang-RT `CcInfo` target; no toolchain provider or build setting. | Owns its Fortran toolchain type/provider and selects the compiler for the execution platform. Compiles with explicit intrinsic module inputs. Passes/propagates Flang-RT `CcInfo`; links with the existing CC toolchain. | Smallest API. A ruleset must include the runtime explicitly, just as it includes its own objects. |
| 2. Named CC link feature (conditional) | Same targets, plus a public `flang_link` CC feature in Hermetic LLVM's known feature set. | Requests `flang_link` only for its own `cc_common.link` action. Continues to pass/propagate Flang-RT `CcInfo`. | Useful if a real target/link mode needs extra Clang link arguments beyond ordinary CC linking. Archive ordering and action inputs must be qualified before the feature may add a runtime archive itself. |
| 3. Global `fortran_link=flang` build setting | Same targets, plus a public build setting that changes the selected CC toolchain runtime library set or link args. | Builds under that configuration, or applies a transition to its link target. | Affects every CC link in that configuration, including unrelated C/C++ targets; a Fortran library still needs transitive `CcInfo` for consumers built outside the mode. Runtime construction must avoid dependency cycles. |

Recommendation for the first implementation: option 1. The probe found no missing CC driver behavior to switch for the first qualified pair. Keep option 2 available if the production probe shows a specific missing link flag or platform rule. Do not create option 3 merely to make the runtime implicit.

## Proposed ownership of the CC link

Hermetic LLVM builds target `runtimes/flang:runtime` from the selected LLVM source and returns ordinary `CcInfo`. This target owns Flang-RT and any target-specific link dependencies required by that runtime, such as `libm` on a qualified glibc target. It is target-configured and version-matched to the host Flang release. Hermetic LLVM does **not** add it to the CC toolchain's `static_runtime_lib`/`dynamic_runtime_lib`, globally enable a Flang feature, or define a Fortran toolchain provider.

A future ruleset owns `FortranToolchainInfo` (name illustrative, not an Hermetic LLVM API). The minimum Flang-backed instance carries: an execution-configured compiler and execution files; target intrinsic `.mod` files and their search directory; and the `CcInfo` from `runtimes/flang:runtime`. It carries no hard-coded target triple or target compile options. Its compiler, intrinsic modules and runtime share one qualified LLVM source identity. The ruleset selects that runtime when constructing the Fortran toolchain; the CC link does not discover it from the object file or a global flag.

For the qualified Linux x86_64-musl pair, the Fortran rule derives Flang's `-target` argument from the target platform's OS, CPU and libc constraints. The same rule separately resolves the CC toolchain for linking; neither the host Flang toolchain provider nor deprecated `CcToolchainInfo.target_gnu_system_name` is the source of target configuration. Hermetic LLVM already derives its own Clang target from these constraints in `toolchain/args/llvm_target_triple.bzl`. The probe must compare the actual Fortran and CC action arguments for agreement. A general ruleset can own the platform-to-Flang-arguments mapping, or an explicitly approved language-neutral Hermetic LLVM configuration API can share it; the initial pair does not require such an API. Other targets may need additional ISA/ABI compile options beyond a triple, so qualify each separately.

For a Fortran executable, the rule passes its compiled objects as `compilation_outputs` and the runtime plus native/Fortran dependency `CcInfo.linking_context`s as `linking_contexts` to `cc_common.link`, along with the selected `CcToolchainInfo` and feature configuration. For a Fortran library, its returned `CcInfo` contains the library's objects/archive and propagates the runtime linking context, so a downstream `cc_binary` with a C/C++ main links the runtime without resolving a Fortran toolchain. The initial probe must verify archive/runtime order and real PIC/non-PIC object selection.

`cc_common.link` itself supplies no Fortran-specific inputs. The **selected Hermetic LLVM CC toolchain** supplies the configured Clang/LLD link action and files, target triple and CPU/ABI flags, CRT/startup objects, libc/sysroot/SDK, compiler builtins, and its configured C++/unwind runtimes. The rule supplies Flang-RT, other Fortran-specific libraries and flags, its objects, and its dependency link graph. `libm`/quadmath/OpenMP are not assumed CC defaults: include each in the Fortran runtime/dependency `CcInfo` only when that target/mode is qualified. Intrinsic modules are compile inputs, never link inputs.

The initial Linux x86_64-musl probe can use a qualified fixed triple. For general target support, the ruleset's toolchain resolution and compiler flags must agree with Hermetic LLVM's selected libc/ABI, not merely OS and CPU. Exposing an additional shared target-configuration API from Hermetic LLVM would need separate approval; it is not part of this first surface.

## Proposed initial public surface under option 1

| Surface | Proposed placement | Purpose |
|---|---|---|
| Flang prebuilt extension/repository | `extensions/flang.bzl`, `prebuilt/flang/`; generated `@flang_prebuilt//:flang` | Resolve the exact LLVM-version host compiler archive. The future ruleset selects the executable through its execution configuration. |
| Intrinsic modules | `runtimes/flang:intrinsic_modules` | Generate target `.mod` files from matching LLVM source with Flang; expose declared files to the ruleset. |
| Flang-RT | `runtimes/flang:runtime` | Ordinary target-configured `CcInfo` for Fortran libraries and final links; include `ISO_Fortran_binding.h` in its compilation context. |

This is one public Bzlmod extension and three public target labels: compiler, intrinsic modules and runtime. No Flang registration repository, Hermetic LLVM Flang toolchain type, custom provider, CC feature, or new build setting in option 1. Internal host-specific archive repositories and module-generation rules are implementation details. The compiler alias and intrinsic-module target shape must be verified in the production probe before freezing the API. All three targets must agree on the LLVM version/source identity. Missing exact-version release or incompatible source override fails clearly.

Option 1 does not change the CC toolchain's target-system metadata or introduce a target triple in the Fortran provider. Both language actions use the same Bazel target platform and are checked for target-option agreement in the probe.

The downstream module continues to register Hermetic LLVM's existing `@llvm_toolchains//:all`. It opts into the Flang extension and calls `use_repo(flang, "flang_prebuilt")`. The future ruleset names `@flang_prebuilt//:flang` in an `attr.label(executable = True, cfg = "exec")` or its own toolchain implementation, and the two runtime labels as target-configured inputs. A bespoke probe rule can use exactly this shape without defining a public Fortran ruleset.

## Release and probe scope

The release archive is the previously approved host-only artifact form: `flang-toolchain-<LLVM version>-<host suffix>.tar.zst`, containing `bin/flang` and only required host files, licenses and provenance. No target libc headers, sysroot, CRT, Flang-RT, target modules, LLD or Clang payload solely for Fortran compiling. Publication remains manual after approval and merge.

Initial qualified pair: Linux x86_64 execution to Linux x86_64 musl target, static executable. The bespoke probe should compile a Fortran main importing intrinsic and user modules; link it via `cc_common.link`; then link a C main against a Fortran library whose `CcInfo` carries Flang-RT. Inspect actual compile/link action inputs and link order. Confirm missing-module and missing-runtime failures. If the existing CC toolchain cannot reproduce the scratch probe with the production archive, identify the precise missing behavior before choosing option 2 or 3.

## Future ruleset: two link backends

Both paths compile source/module units with the selected Fortran compiler into declared `.o`/`.mod` outputs. The link backend is a separate choice; module dependency ordering still requires individual compile actions.

| Backend | Link owner | Required toolchain environment | Status with minimal Flang archive |
|---|---|---|---|
| CC link | `cc_common.link` with the selected C++ toolchain | Target Flang-RT `CcInfo`, Fortran/native object and library inputs, and the CC toolchain's normal CRT/libc/builtins/linker closure. | Demonstrated for a Linux x86_64-musl static executable in a scratch probe. Recommended initial backend for Hermetic LLVM integration. |
| Fortran driver link | `flang <objects> ... -o <output>` in a ruleset-owned action | A complete target-aware Flang driver installation or explicit target sysroot, linker executable/files, startup objects, builtins, Flang-RT, libc/math/SDK libraries, search paths and flags. These are declared action inputs if the build is hermetic. | The same `bin/flang` can be the driver, but the minimal archive alone is insufficient. No Hermetic LLVM-composed driver link has been demonstrated. |

A future ruleset may define one generic Fortran toolchain type/provider with compiler inputs plus explicit link capabilities, and choose a backend per target or configuration. A driver-link backend would require a fully declared, hermetic toolchain installation and target dependency closure. Runtime `.mod` and archive versions must match the selected compiler in either path.

Do not pass Clang to Flang's `--ld-path` and expect a Clang-driver link: Flang sends raw linker arguments to the selected external linker. Reusing Hermetic LLVM's cross environment for a Flang-driver action would need an explicit, tested mapping of its CRT, sysroot, builtins, library ordering and linker files. The initial release does not need that mapping for the proven CC link path. The ruleset can add driver-link support independently for full or local toolchains while the Hermetic LLVM composition remains CC-owned.

## Decision requested

Agree on whether the first API should be option 1, or name the specific CC behavior that should be selected by a feature or build setting now. Toolchain and provider design stays with the future ruleset.
