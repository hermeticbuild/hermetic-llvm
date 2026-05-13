# Port libstdc++ configure checks into structured Bazel modules

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan lives in `.agents/plans/libstdcxx-configure-checks.md` and must be maintained together with the repository's existing libstdc++ work plan in `.agents/plans/libstdcxx-from-source.md`.

## Purpose / Big Picture

The current libstdc++ Bazel port has a monolithic `runtimes/libstdcxx/config_checks.bzl` file that mixes autoconf-style probes, libstdc++ policy decisions, and target-specific shortcuts. That makes it hard to compare the port against GCC updates, and it already allowed gaps because `configure.host` and `crossconfig.m4` were not in the sparse GCC repository.

After this plan is implemented, the Bazel port will have Starlark files that mirror the shape of GCC's configure inputs. A maintainer updating GCC can compare `libstdc++-v3/acinclude.m4`, `libstdc++-v3/crossconfig.m4`, top-level GCC config macros, and `libstdc++-v3/configure.ac` against matching Bazel files. The active generated `config.h` will still only perform checks that matter for the current supported configuration, Linux with GNU libc, while unsupported target branches remain present as commented-out porting notes with explicit reasons.

The implementation must not run `make`, `./configure`, autoconf, Python, or GCC build scripts. Probe execution must continue to use Bazel actions and the selected `cc_toolchain`, so libc headers and target flags come from Bazel's C/C++ toolchain rather than handcrafted include paths.

## Progress

- [x] (2026-05-13) Added `libstdc++-v3/configure.host` and `libstdc++-v3/crossconfig.m4` to the sparse GCC archive roots in `3rd_party/gcc/extension/gcc.bzl`.
- [x] (2026-05-13) Exported `@gcc//:libstdc++-v3/configure.host` and `@gcc//:libstdc++-v3/crossconfig.m4` from `3rd_party/gcc/gcc.BUILD.bazel`.
- [x] (2026-05-13) Verified the new files appear in `bazel query '@gcc//:*'`.
- [x] (2026-05-13) Created this first ExecPlan.
- [x] (2026-05-13) Added the top-level GCC config macro files needed by libstdc++ native checks to the sparse GCC fetch and exports.
- [x] (2026-05-13) Replaced the monolithic `runtimes/libstdcxx/config_checks.bzl` shape with source-counterpart modules and direct `config_probe.bzl` imports.
- [x] (2026-05-13) Updated `configure.report.md` from the now-complete fetched source set and recorded completed source-split work.
- [x] (2026-05-13) Expanded the existing audit test to include `crossconfig.m4` and selected top-level GCC config macros.
- [x] (2026-05-13) Added macro-call coverage to `config_define_audit_test` so it tracks called `GLIBCXX_*` and `GCC_*` macros, not only defines.
- [x] (2026-05-13) Replaced the policy-defined C99 and TR1 aggregate outputs with Linux GNU probes modeled after `GLIBCXX_ENABLE_C99` and `GLIBCXX_CHECK_C99_TR1`; `HAVE_GETIPINFO` and `_GLIBCXX_USE_LFS` were already fixed.
- [x] (2026-05-13) Split define audit statuses so directly modeled defines distinguish `probe-modeled` from `policy-modeled`.
- [x] (2026-05-13) Resolved `AC_SYS_LARGEFILE` for the current scope: no active define is needed for supported 64-bit Linux GNU targets; 32-bit or Darwin targets must revisit it.
- [x] (2026-05-13) Added `libstdc++-v3/linkage.m4` to the sparse GCC fetch and audit data so math/stdlib helper macros are checked directly.
- [x] (2026-05-13) Modeled `_GLIBCXX_USE_WCHAR_T` as the upstream wide API declaration probe instead of a fixed policy define.
- [x] (2026-05-13) Updated the configure report and source-counterpart file headers to document where the Bazel checks were ported from.

## Surprises & Discoveries

- Observation: The sparse GCC archive originally fetched `libstdc++-v3/acinclude.m4` and `libstdc++-v3/configure.ac`, but not `configure.host` or `crossconfig.m4`.

  Evidence: before the sparse archive edit, `find .../external/+gcc+gcc/libstdc++-v3 -name configure.host -o -name crossconfig.m4` returned no files. After the edit, `bazel query '@gcc//:*'` lists `@gcc//:libstdc++-v3/configure.host` and `@gcc//:libstdc++-v3/crossconfig.m4`.

- Observation: Top-level GCC `config/*.m4` macro files and `libstdc++-v3/linkage.m4` were not originally in the sparse archive, so audit coverage had blind spots.

  Evidence: the sparse archive was extended to include only the specific top-level `config/*.m4` files used by libstdc++ configure logic and `libstdc++-v3/linkage.m4`; `config_define_audit_test` now receives those files through runfiles.

## Decision Log

- Decision: Keep this plan in `.agents/plans/` rather than outside the repository.

  Rationale: The task is part of the existing libstdc++ branch work, and the repository already has `.agents/plans/libstdcxx-from-source.md` as the durable plan for this project.

  Date/Author: 2026-05-13 / Corentin Kerisit

- Decision: Model the new structure as source-counterpart Starlark modules and do not keep `config_checks.bzl` as a compatibility aggregator.

  Rationale: The split is still uncommitted, so the caller can move directly to `runtimes/libstdcxx/configure_ac_checks.bzl` without preserving an old import path.

  Date/Author: 2026-05-13 / Corentin Kerisit

- Decision: The first active scope is Linux with GNU libc only.

  Rationale: The current libstdc++ runtime support is intended for Linux GNU dynamic libstdc++. Unsupported branches should be ported as documented comments, not active checks, so they remain visible for future target work without changing current behavior.

  Date/Author: 2026-05-13 / Corentin Kerisit

## Outcomes & Retrospective

Milestone update on 2026-05-13: the source fetch and source-counterpart split are implemented directly without a compatibility facade. `config_probe.bzl` imports `configure_ac_checks.bzl`, and the deleted monolithic file is no longer in the build graph.

Validation on 2026-05-13: `bazel run //internal_tools:buildifier.check`, `bazel build --config remote //runtimes/libstdcxx:config_h //runtimes/libstdcxx:config_probe //runtimes/libstdcxx:configure_ac_checks`, `bazel test --config remote //runtimes/libstdcxx:config_define_audit_test`, and the `e2e/rules_cc` libstdc++ dynamic output tests all passed.

Milestone update on 2026-05-13: the audit now extracts direct `GLIBCXX_*` and `GCC_*` macro calls, `AC_REQUIRE`, and `AC_BEFORE` references from `libstdc++-v3/configure.ac`, `libstdc++-v3/acinclude.m4`, and `libstdc++-v3/crossconfig.m4`. The checked-in `runtimes/libstdcxx/config_macro_status.txt` classifies each discovered macro call as modeled, target-derived, future build setting, not needed, or unsupported. Grouped modeled macros have explicit source anchors in `runtimes/libstdcxx/acinclude_checks.bzl` so GCC updates fail visibly instead of silently bypassing the Bazel model.

Milestone update on 2026-05-13: `glibcxx_enable_c99()` and `glibcxx_check_c99_tr1()` no longer policy-define their aggregate C99/TR1 outputs. The Linux GNU model now uses compile or link probes for the C++98 math, complex, stdio, stdlib, and wchar groups; the C++11 stdint, inttypes, math, complex, stdio, stdlib, wchar, ctype, and fenv groups; and the TR1 complex, ctype, fenv, stdint, math, and inttypes groups. Generated `config_h.json` shows the expected Linux GNU C99 and TR1 outputs still evaluate true.

Milestone update on 2026-05-13: `config_define_status.txt` now separates `probe-modeled` entries from `policy-modeled` entries. The audit still requires both categories to appear in the Bazel model sources, but future report work can now identify remaining fixed policies without reclassifying probe-backed defines by hand.

Milestone update on 2026-05-13: `AC_SYS_LARGEFILE` was reviewed against `runtimes/libstdcxx/configure.bzl` and `runtimes/libstdcxx/headers.bzl`. The active supported GNU libstdc++ targets are 64-bit Linux triples, so no `_FILE_OFFSET_BITS` or `_LARGE_FILES` define is needed today. `libstdcxx_largefile_config_header` already forwards those defines from `config_h`, so adding 32-bit GNU or Darwin support should add the relevant config entries rather than changing the header plumbing.

Milestone update on 2026-05-13: `libstdc++-v3/linkage.m4` is now fetched and audited. Its math and stdlib helper macros are represented by `gcc_check_math_support()` and `gcc_check_stdlib_support()`, including `HAVE_FPCLASS` and `HAVE_QFPCLASS` in the discovered define set. `_GLIBCXX_USE_WCHAR_T` now follows the upstream `GLIBCXX_ENABLE_WCHAR_T` wide API declaration group.

## Context and Orientation

GCC's libstdc++ configuration is spread across several source files. `libstdc++-v3/configure.ac` is the main autoconf script. It decides the top-level order of policy choices and probes. `libstdc++-v3/acinclude.m4` defines most libstdc++-specific macros, such as `GLIBCXX_ENABLE_C99`, `GLIBCXX_CHECK_LFS`, and `GLIBCXX_ENABLE_SYMVERS`. `libstdc++-v3/linkage.m4` defines helper macros for math and stdlib declaration/linkage checks. `libstdc++-v3/configure.host` is a shell file sourced by configure to choose CPU, OS, ABI, header, and source directories from the host triple. `libstdc++-v3/crossconfig.m4` contains hardcoded define choices for non-native or cross builds. GCC also has top-level `config/*.m4` macro files used by libstdc++, for example unwind, futex, CET, and generic compiler/linker helper macros.

In this repository, `3rd_party/gcc/extension/gcc.bzl` defines the sparse source archive for GCC. `3rd_party/gcc/gcc.BUILD.bazel` exports files and builds the translated libstdc++ source targets. `runtimes/libstdcxx/configure.bzl` maps Bazel platform constraints to values that currently mimic parts of `configure.host`. The config.h probe and policy definitions are split across `runtimes/configure/native_autoconf_checks.bzl`, `runtimes/libstdcxx/acinclude_checks.bzl`, `runtimes/libstdcxx/crossconfig_checks.bzl`, and `runtimes/libstdcxx/configure_ac_checks.bzl`. `runtimes/libstdcxx/config_probe.bzl` executes those probes with the Bazel C/C++ toolchain and writes generated `config.h` outputs.

An autoconf probe is a small compile, link, preprocess, run, header, function, declaration, or tool check used by configure to decide whether a macro should be defined. In this Bazel port, probes are represented as Starlark data and executed by Bazel actions. A policy is a choice made from configure options, target triples, or current support scope rather than from compiling a snippet.

## Plan of Work

First, complete the source basis. The sparse GCC archive must include every upstream file used as a source of truth for the active configure model. `configure.host` and `crossconfig.m4` are already added. The next fetch step is to add the top-level `config/*.m4` files that define macros called directly or indirectly from `configure.ac` and `acinclude.m4`. Do not fetch the entire GCC repository; list only the needed macro files so the sparse checkout remains small.

Second, split the Starlark definitions by upstream counterpart. Create a generic native autoconf module, tentatively `runtimes/configure/native_autoconf_checks.bzl`, for reusable checks that are not libstdc++-specific: header checks, function checks, declaration checks, compiler feature checks, linker feature checks, TLS, iconv, futex, unwind IP info, and related GCC top-level macros. This file must avoid libstdc++ policy names unless the upstream macro itself is GCC-generic. It should export small functions returning check structs, such as `check_headers(...)`, `check_funcs(...)`, and named equivalents of GCC macros where the macro has target policy.

Third, create `runtimes/libstdcxx/acinclude_checks.bzl` as the counterpart of `libstdc++-v3/acinclude.m4`. This file should define functions named after the libstdc++ macros where practical, for example `glibcxx_enable_c99(...)`, `glibcxx_check_c99_tr1(...)`, `glibcxx_check_lfs(...)`, `glibcxx_enable_libstdcxx_time(...)`, and `glibcxx_enable_symvers(...)`. Each function should return structured data: compile checks, link checks, policy defines, string defines, or substitutions. Where a GCC macro mixes active Linux GNU checks with unsupported target branches, active data should be returned for Linux GNU and unsupported branches should be preserved as commented-out blocks with a comment explaining the condition and why it is inactive.

Fourth, create `runtimes/libstdcxx/crossconfig_checks.bzl` as the counterpart of `libstdc++-v3/crossconfig.m4`. For now, Linux GNU cross behavior should be represented only to the extent it applies to the current supported Linux GNU configuration. Branches for newlib, picolibc, Darwin, BSD, MinGW, RTEMS, VxWorks, and others should be porting comments, not active checks, each with a short reason such as "unsupported target family" or "non-GNU libc unsupported for libstdc++ today." This makes future GCC update review possible without changing current support.

Fifth, create `runtimes/libstdcxx/configure_ac_checks.bzl` as the counterpart of `libstdc++-v3/configure.ac`. This file should be the only place that composes the full active `config.h` plan. It should read like configure's control flow: hosted policy, compiler-only checks, variable runtime options, OS checks, native Linux GNU checks, unwind/futex/symvers/ABI checks, filesystem/networking/time/debugging checks, and build-only macros marked not needed. It should call functions from `acinclude_checks.bzl`, `crossconfig_checks.bzl`, and `runtimes/configure/native_autoconf_checks.bzl`. Unsupported configure branches should be visible as commented-out calls with a reason before each block.

Sixth, delete `runtimes/libstdcxx/config_checks.bzl` and update `runtimes/libstdcxx/config_probe.bzl` to import `COMPILE_CHECKS`, `LINK_CHECKS`, and `POLICY_DEFINES` directly from `runtimes/libstdcxx/configure_ac_checks.bzl`. This keeps the source-counterpart split explicit and avoids a stale compatibility layer.

Seventh, strengthen the audit machinery. Add a shell-based audit test, not Python, that extracts macro definitions and uses from the fetched upstream files and compares them against a Starlark-maintained status file or explicit expected list. The first version should track `AC_DEFINE`, `AC_DEFINE_UNQUOTED`, `AC_CHECK_HEADERS`, `AC_CHECK_FUNCS`, `AC_CHECK_DECL`, called `GLIBCXX_*` macros, and called `GCC_*` macros. The test should fail with a clear list of missing symbols or macro calls when GCC changes.

Eighth, update `configure.report.md` after the split. The report should be regenerated or rewritten from the complete source set, including `configure.host`, `crossconfig.m4`, and top-level config macro files. It should stop making claims based on missing files. The checklist should use the same categories as the new modules: active Linux GNU probe, active Linux GNU policy, unsupported target branch, build-only/not needed, and future build setting.

Ninth, fix the correctness issues discovered by the audit. `HAVE_GETIPINFO` must model `_Unwind_GetIPInfo` or GCC's target policy, not `getaddrinfo`. `_GLIBCXX_USE_LFS` must use GCC's full `GLIBCXX_CHECK_LFS` group. C99 and TR1 groups must either become aggregate probes or have explicit hosted-glibc policy justification in the source-counterpart files.

## Concrete Steps

Run all commands from `/home/corentin/llvm`.

1. Confirm the new sparse files are visible:

       bazel query '@gcc//:*' | rg 'libstdc\\+\\+-v3/(configure.host|crossconfig.m4)'

   Expected output includes:

       @gcc//:libstdc++-v3/configure.host
       @gcc//:libstdc++-v3/crossconfig.m4

2. Identify and fetch the remaining top-level config macro files:

       rg -n 'GCC_[A-Z0-9_]+|ACX_[A-Z0-9_]+' \
         $(bazel info output_base)/external/+gcc+gcc/libstdc++-v3/configure.ac \
         $(bazel info output_base)/external/+gcc+gcc/libstdc++-v3/acinclude.m4

   Then add only the needed `config/*.m4` files to `_GCC_ARCHIVE_INCLUDES` and `exports_files`.

3. Add the new Starlark modules:

       runtimes/configure/native_autoconf_checks.bzl
       runtimes/libstdcxx/acinclude_checks.bzl
       runtimes/libstdcxx/crossconfig_checks.bzl
       runtimes/libstdcxx/configure_ac_checks.bzl

   Update `runtimes/libstdcxx/config_probe.bzl` to load from `configure_ac_checks.bzl`; do not keep a compatibility facade.

4. Run formatting:

       bazel run //internal_tools:buildifier.check

5. Build generated config outputs:

       bazel build --config remote //runtimes/libstdcxx:config_h

6. Run the libstdc++ e2e smoke that proves the runtime still works:

       cd e2e/rules_cc
       bazel test --config remote //:libstdcxx_main_dynamic_output_test //:libstdcxx_main_dynamic_with_linkopts_output_test

7. After adding the audit test, run:

       bazel test --config remote //runtimes/libstdcxx:configure_sources_audit_test

## Validation and Acceptance

The refactor is accepted when `bazel run //internal_tools:buildifier.check` passes, `bazel build --config remote //runtimes/libstdcxx:config_h` produces the same generated `config.h` decisions for the active Linux GNU configuration unless an intentional fix is documented, and the e2e `rules_cc` libstdc++ dynamic runtime tests pass under `--config remote`.

The audit part is accepted when changing a fetched upstream configure source to add a new `AC_DEFINE`, `AC_CHECK_HEADERS`, `AC_CHECK_FUNCS`, called `GLIBCXX_*`, or called `GCC_*` macro causes `//runtimes/libstdcxx:configure_sources_audit_test` to fail with a readable missing-item message.

The source-structure part is accepted when a maintainer can open the upstream GCC file and the Bazel counterpart side by side and follow the same order: `acinclude.m4` to `acinclude_checks.bzl`, `crossconfig.m4` to `crossconfig_checks.bzl`, top-level `config/*.m4` to `native_autoconf_checks.bzl`, and `configure.ac` to `configure_ac_checks.bzl`.

## Idempotence and Recovery

All edits are additive or mechanical splits except deleting the old monolithic `config_checks.bzl`. If a split produces a behavior change, stop and compare the generated `config_h` summary before continuing. Recovery is to restore `config_checks.bzl` from git and point `config_probe.bzl` back to it, but that should only be needed if the direct split cannot be made green.

Do not delete unsupported target notes just because they are inactive. If a branch is out of scope, leave it commented with the upstream condition and the reason it is inactive. This preserves the audit trail for later platform work.

Do not introduce Python scripts for audit extraction. Use `sh_test` and standard POSIX tools already available in the test environment.

## Artifacts and Notes

Initial fetch verification:

    $ bazel query '@gcc//:*'
    ...
    @gcc//:libstdc++-v3/configure.ac
    @gcc//:libstdc++-v3/configure.host
    @gcc//:libstdc++-v3/crossconfig.m4
    ...

Known remaining correctness work from the current report:

- Build-setting-backed policies still need a real knob layer for options such as verbose mode, concept checks, decimal float, float128, fully dynamic string, and emergency EH pool sizing.
- Target-derived policies still need broader matrix validation before adding non-Linux-GNU libstdc++ support.
- Unsupported branches for newlib, picolibc, Darwin, Solaris, Windows, RTEMS, VxWorks, and libbacktrace should stay visible in the report until those targets are deliberately supported or rejected.
