# libstdc++ Bazel Porting Guide

This file defines the protocol for porting GCC libstdc++ source and configure
logic into Bazel. It applies to files under `runtimes/libstdcxx` and the
matching GCC source declarations in `3rd_party/gcc`.

The scope here is the libstdc++ Bazel port itself: source lists, generated
headers, header overlays, configure checks, and configure-derived policy. This
file does not describe C++ standard library selection, cc toolchain declaration,
or downstream toolchain integration.

## Core Rule

Do not port checks by memory or by manually scanning one file. First build a
mechanical inventory from the GCC sources, then classify every item, then port
the active supported behavior, then validate that the inventory and Bazel model
still agree.

Every GCC check, macro, define, substitution, conditional, and target branch
must end up in exactly one of these states:

- `probe-modeled`: represented by a Bazel compile, link, declaration, header,
  or other toolchain-backed probe.
- `policy-modeled`: represented by a fixed or target-derived Bazel policy.
- `target-derived`: selected from Bazel target/platform information.
- `build-setting-later`: currently fixed, but should become an explicit private
  build setting before claiming full knob parity.
- `not-needed`: configure/build/install/testsuite plumbing that Bazel replaces.
- `unsupported-target`: target family not supported by this libstdc++ port.
- `unsupported-feature`: optional libstdc++ feature not built by this port.

Avoid a vague `unsupported` state. Say whether the item is unsupported because
the target family is out of scope or because the feature is out of scope.

## Source Counterparts

Keep Bazel files shaped like the GCC files they port:

- `runtimes/libstdcxx/configure.ac.bzl` is the active
  counterpart of `libstdc++-v3/configure.ac`. It composes the supported
  configure flow.
- `runtimes/libstdcxx/acinclude.m4.bzl` is the counterpart of
  `libstdc++-v3/acinclude.m4`.
- `runtimes/libstdcxx/crossconfig.m4.bzl` is the counterpart of
  `libstdc++-v3/crossconfig.m4`.
- `runtimes/libstdcxx/gcc_config_checks.bzl` is the counterpart
  for GCC top-level `config/*.m4` checks used by libstdc++.
- `runtimes/libstdcxx/linkage.m4.bzl` is the counterpart of
  `libstdc++-v3/linkage.m4`.
- `runtimes/libstdcxx/autoconf/checks.bzl`,
  `runtimes/libstdcxx/autoconf/autoconf_config.bzl`,
  `runtimes/libstdcxx/autoconf/autoconf_hdr.bzl`,
  `runtimes/libstdcxx/autoconf/cc_configure_probe.bzl`, and
  `runtimes/libstdcxx/autoconf/providers.bzl` are local generic
  autoconf mechanics. They should stay free of libstdc++ source-policy
  decisions so a future external autoconf ruleset migration is a thin adapter
  change.
- `libstdc++-v3/linkage.m4` helpers are represented in
  `runtimes/libstdcxx/linkage.m4.bzl`, even when they are generic math or
  stdlib declaration/linkage checks.
- `runtimes/libstdcxx/target_config.bzl`,
  `runtimes/libstdcxx/libstdcxx_cxxconfig_header.bzl`,
  `runtimes/libstdcxx/libstdcxx_gthr_headers.bzl`,
  `runtimes/libstdcxx/libstdcxx_largefile_config_header.bzl`,
  `runtimes/libstdcxx/libstdcxx_symbols_version_script.bzl`, and `BUILD.bazel` may
  consume configure-derived policy, but should not hide new configure semantics
  without updating the inventories.

Each source-counterpart `.bzl` file should start with a short comment naming
the GCC file(s) it was ported from. When a group of upstream macros is collapsed
into one Bazel helper, leave an anchor comment listing the upstream macro names.

## Required Tracking Files

Maintain these human-readable tracking files in `runtimes/libstdcxx/docs`:

- `autoconf.checks.md`: checklist of check definitions available from GCC
  sources. This covers GCC top-level `config/*.m4` macros, libstdc++ custom
  `GLIBCXX_*` macros, and helper macros such as those in `linkage.m4`.
- `autoconf.usage.md`: checklist of configure usage, in the order
  `configure.ac` uses checks and macros. This file explains which definitions
  are actually reached for the current supported Linux GNU configuration and
  which branches are inactive.
- `autoconf.README.md`: glossary and report for the configure model. For every
  check, it records what the upstream check does, when it runs, what outputs it
  produces, and the Bazel status.

The lower-level machine status files, such as `config_define_status.txt` and
`config_macro_status.txt`, also live in `runtimes/libstdcxx/docs` as audit
inputs. They should agree with the three Markdown files, but they are not a
substitute for the glossary.

## Inventory Scripts

The inventory must be scriptable and reproducible. Scripts should live in
`runtimes/libstdcxx/tests` and be exposed through Bazel tests or runnable
targets.

The current entry point is `runtimes/libstdcxx/tests/autoconf_inventory.sh`.
Its `inventory` mode prints raw discoveries: macro definitions, macro uses,
config defines, check form counts, and check arguments. Raw discoveries are not
checklist entries by themselves. Run
`bazel run //runtimes/libstdcxx/tests:autoconf_inventory -- inventory` to
inspect that raw queue through Bazel runfiles. The Bazel target
`//runtimes/libstdcxx/tests:config_define_audit_test`
uses `check-status` mode to verify status coverage and modeled-source
references. The Bazel target
`//runtimes/libstdcxx/tests:autoconf_inventory_test` uses `check-docs` mode to
verify that the Markdown checklists and glossary mention every status-tracked
configure macro and every reviewed concrete `AC_ARG_*`, `AC_CHECK_*`, and
`AC_COMPUTE_INT` argument.

The scripts should read the fetched GCC source files from Bazel runfiles, not
from an arbitrary local GCC checkout. They should cover at least:

- `libstdc++-v3/configure.ac`
- `libstdc++-v3/acinclude.m4`
- `libstdc++-v3/linkage.m4`
- `libstdc++-v3/crossconfig.m4`
- `libstdc++-v3/configure.host`
- selected top-level GCC `config/*.m4` files exported by `@gcc`

The inventory must extract:

- macro definitions such as `AC_DEFUN([GLIBCXX_*])` and `AC_DEFUN([GCC_*])`;
- macro uses, including direct calls, `AC_REQUIRE`, and `AC_BEFORE`;
- config defines from `AC_DEFINE`, `AC_DEFINE_UNQUOTED`, and `AH_VERBATIM`;
- header, function, declaration, type, member, compile, link, run, and compute
  checks;
- substitutions and conditionals from `AC_SUBST`, `AM_CONDITIONAL`, and
  `GLIBCXX_CONDITIONAL`;
- target branches and option branches that change source lists, headers, flags,
  ABI, or generated config output.

Scripts must fail when GCC adds a discovered status-tracked item that is missing
from the tracking files. They should print the missing upstream symbol or macro
name and the source file where it was discovered. Raw concrete check arguments
are a review queue until they have been mapped to an implementation or explicit
classification.

Do not run `make`, `./configure`, autoconf, automake, libtool, or GCC build
scripts to produce the inventory. The inventory is a static source audit.

## Porting Protocol

Follow this sequence for every configure-check change and every GCC update:

1. Refresh the GCC sparse source list only as needed. Do not fetch all GCC
   sources just to inspect configure logic. Add explicit files to
   `3rd_party/gcc/extension/gcc.bzl` and export them from
   `3rd_party/gcc/gcc.BUILD.bazel`.
2. Run the inventory scripts. Treat their output as a review queue, not as a
   completed checklist. Update `runtimes/libstdcxx/docs/autoconf.checks.md`,
   `runtimes/libstdcxx/docs/autoconf.usage.md`, and
   `runtimes/libstdcxx/docs/autoconf.README.md` only for checks that are
   implemented, target-derived, deliberately deferred, not needed, or
   explicitly out of scope.
3. Classify every new or changed item before editing probe behavior. Use the
   status vocabulary from this file.
4. Port active Linux GNU behavior into the source-counterpart `.bzl` file that
   matches the upstream source. Keep unsupported target branches documented as
   inactive notes with the upstream condition and a reason.
5. Prefer Bazel-native structure. Use normal Bazel targets, `cc_library` deps,
   generated headers, and existing helper rules before adding a custom rule.
6. For configure probes, use the selected Bazel C/C++ toolchain. Do not
   manually synthesize libc include paths or compiler command lines. If a probe
   rule needs to compile or link, it must get compiler, linker, system include,
   and target flags from the toolchain.
7. Keep temporary shell actions small. `run_shell` is acceptable for now, but
   design probe data and actions so the shell runner can later be replaced for
   Windows portability.
8. Do not use Python for configure inventory or probe execution unless this
   policy is explicitly changed. Prefer shell plus standard text tools for the
   audit scripts.
9. Update `runtimes/libstdcxx/docs/config_define_status.txt` and
   `runtimes/libstdcxx/docs/config_macro_status.txt` only after the Markdown
   checklists and glossary explain the semantic status. Do not mark a check
   `modeled` merely because the inventory found it.
10. Validate with the package audit tests, generated config targets, and a
    real `e2e/rules_cc` smoke test when behavior changes.

## Modeling Rules

Use a probe when GCC determines the answer by compiling, linking, checking a
declaration, or inspecting headers for the target. Use policy only when GCC's
answer is a configure option, an installation/build-system concern, or a target
decision that Bazel already knows through constraints.

When GCC uses an aggregate check, preserve the aggregate shape unless there is
a clear reason to split it. If a split is needed, the checklist and glossary
must explain how the split maps back to upstream.

When GCC has native and cross behavior, document both. Only activate the
current supported Linux GNU path unless the libstdc++ support matrix has been
expanded deliberately.

When GCC substitutes source paths, version scripts, headers, or flags, treat
that as configure behavior even if it does not create a `config.h` define. It
still belongs in the usage checklist and glossary.

## Validation

Before committing configure-check changes, run from the repository root:

    bazel run //internal_tools:buildifier.check
    bazel build --config remote //runtimes/libstdcxx:config_h //runtimes/libstdcxx:libstdcxx_config_h //runtimes/libstdcxx:target_config //runtimes/libstdcxx/autoconf:autoconf_config //runtimes/libstdcxx/autoconf:autoconf_hdr //runtimes/libstdcxx/autoconf:checks //runtimes/libstdcxx/autoconf:cc_configure_probe //runtimes/libstdcxx:gcc_config_checks //runtimes/libstdcxx:linkage_checks //runtimes/libstdcxx:configure_ac_checks
    bazel test --config remote //runtimes/libstdcxx/tests:autoconf_inventory_test
    bazel test --config remote //runtimes/libstdcxx/tests:config_define_audit_test

When the change can affect real runtime behavior, also run from
`e2e/rules_cc`:

    bazel test --config remote //:libstdcxx_main_dynamic_output_test //:libstdcxx_main_dynamic_with_linkopts_output_test

For a GCC update, the acceptance condition is not only that Bazel builds. The
inventory scripts must show that every upstream configure item is classified in
the checklists and described in `autoconf.README.md`.
