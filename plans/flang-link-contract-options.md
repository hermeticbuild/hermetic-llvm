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

## Proposed initial public surface under option 1

| Surface | Proposed placement | Purpose |
|---|---|---|
| Flang prebuilt extension/repository | `extensions/flang.bzl`, `prebuilt/flang/`; generated `@flang_prebuilt//:flang` | Resolve the exact LLVM-version host compiler archive. The future ruleset selects the executable through its execution configuration. |
| Intrinsic modules | `runtimes/flang:intrinsic_modules` | Generate target `.mod` files from matching LLVM source with Flang; expose declared files to the ruleset. |
| Flang-RT | `runtimes/flang:runtime` | Ordinary target-configured `CcInfo` for Fortran libraries and final links; include `ISO_Fortran_binding.h` in its compilation context. |

This is one public Bzlmod extension and three public target labels: compiler, intrinsic modules and runtime. No Flang registration repository, Hermetic LLVM Flang toolchain type, custom provider, CC feature, or new build setting in option 1. Internal host-specific archive repositories and module-generation rules are implementation details. The compiler alias and intrinsic-module target shape must be verified in the production probe before freezing the API. All three targets must agree on the LLVM version/source identity. Missing exact-version release or incompatible source override fails clearly.

The downstream module continues to register Hermetic LLVM's existing `@llvm_toolchains//:all`. It opts into the Flang extension and calls `use_repo(flang, "flang_prebuilt")`. The future ruleset names `@flang_prebuilt//:flang` in an `attr.label(executable = True, cfg = "exec")` or its own toolchain implementation, and the two runtime labels as target-configured inputs. A bespoke probe rule can use exactly this shape without defining a public Fortran ruleset.

## Release and probe scope

The release archive is the previously approved host-only artifact form: `flang-toolchain-<LLVM version>-<host suffix>.tar.zst`, containing `bin/flang` and only required host files, licenses and provenance. No target libc headers, sysroot, CRT, Flang-RT, target modules, LLD or Clang payload solely for Fortran compiling. Publication remains manual after approval and merge.

Initial qualified pair: Linux x86_64 execution to Linux x86_64 musl target, static executable. The bespoke probe should compile a Fortran main importing intrinsic and user modules; link it via `cc_common.link`; then link a C main against a Fortran library whose `CcInfo` carries Flang-RT. Inspect actual compile/link action inputs and link order. Confirm missing-module and missing-runtime failures. If the existing CC toolchain cannot reproduce the scratch probe with the production archive, identify the precise missing behavior before choosing option 2 or 3.

## Decision requested

Agree on whether the first API should be option 1, or name the specific CC behavior that should be selected by a feature or build setting now. Toolchain and provider design stays with the future ruleset.
