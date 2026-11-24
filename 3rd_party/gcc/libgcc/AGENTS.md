# libgcc Bazel Port

This package builds libgcc (`libgcc.a`, `libgcc_eh.a`, `libgcc_s.so.1`) from
the selected GCC repository with the toolchain's Clang. The BUILD targets live
in `3rd_party/gcc/gcc.BUILD.bazel`; this package holds their data and rules.
`//runtimes/cxxstdlib` links them in place of LLVM's libunwind where
`//runtimes/libgcc:libgcc_from_gcc` matches: the GCC versions in
`LIBGCC_TARGETS` in `3rd_party/gcc/version.bzl`, each on the Linux CPUs listed
for it. Each libstdc++ version links the libgcc built from its own GCC sources.
`runtimes/libgcc/BUILD.bazel` also has GCC's `libgcc_s.so` linker script and
`:libgcc_library_search_directory`, where dynamic links find it with `-lgcc_s`.

## Files

- `makefile.bzl` ports the object lists of `libgcc/Makefile.in` and the tmake
  fragments `libgcc/config.host` selects, which `_TMAKE_FILES` lists for GCC 17
  and `libgcc_tmake_files` adjusts for older versions. Each fragment's
  contribution is marked with its file name. Keep the fragments in config.host
  order, since later ones reassign variables. `_features` names the GCC versions
  where the object lists change.
- `target_config.bzl` holds what GCC's build directory and libgcc's configure
  would provide: `tm.h`, `tconfig.h`, the parts of `auto-host.h` that libgcc
  reads, `libgcc_tm.h`, the `-fbuilding-libgcc` predefines, and shims for GCC
  builtins Clang lacks.
- `configure.ac.bzl` ports `libgcc/configure.ac`'s checks as autoconf checks
  that run with the toolchain of the platform libgcc builds for. Each is a
  probe, where configure's check fits this toolchain, or a fixed policy value,
  where it does not. The results write `auto-target.h` and
  `libgcc_configure_cflags.h`, which holds the `-D` flags configure puts in
  `INTERNAL_CFLAGS`. `LIBGCC_SELECTION_CHECKS` holds the results that decide
  what the build includes: what `config.host` and `config.gcc` select, and the
  results that `Makefile.in`'s conditionals read. Only the configure tests use
  that list, because the build needs the selections at loading time, before
  probes can run.
- `configure_define_status.txt` gives each macro in `libgcc/config.in` a
  status, and `configure_subst_status.txt` each `@VAR@` substitution in
  `libgcc/Makefile.in`. Each file's header defines its statuses.
- `libgcc_rules.bzl` has the wrapper-source, hide-list and version-map rules.
- `3rd_party/gcc/patches/14-17/libgcc-clang-compat.patch` and
  `3rd_party/gcc/patches/10.x/libgcc-clang-compat.patch` change the spots in
  libgcc's sources that rely on GCC-only behavior, so that Clang compiles them.
- `3rd_party/gcc/patches/10.x/libgcc-morestack-init-array.patch` backports how
  GCC 14's `morestack.S` registers `__stack_split_initialize` in `.init_array`.
  GCC 10 registers it in `.ctors`. lld keeps `.ctors` apart from `.init_array`,
  and compiler-rt's `crtbegin.o` does not run `.ctors`.
- `3rd_party/gcc/patches/17.x/libgcc-clang-aarch64-unwind.patch` replaces the
  `__builtin_eh_return` in libgcc's unwinder, which Clang does not implement
  for AArch64.

## Where the values come from

Derive each value from GCC itself, not from memory:

- Object lists: configure libgcc for the target and compare
  `make -n libgcc.a libgcc_eh.a libgcc_s.so` against `libgcc_objects()`. The
  names, sources and per-object flags must match exactly.
- Predefines: `xgcc -fbuilding-libgcc -dM -E -x c /dev/null | grep __LIBGCC_`
  from a GCC of the same version built for the target (`make all-gcc` is
  enough). Check `__libgcc_cmp_return__` and `__libgcc_shift_count__` sizes
  the same way; they differ between targets.
- `tm.h`: the `tm_file` list and `tm_defines` from GCC's configure for the
  target. The configure tests check these lists, the `libgcc_tm.h` list, the
  header links and the tmake fragments against what `config.gcc` and
  `config.host` select.
- `auto-host.h`: set the macros as fixed policy, as GCC's configure sets them
  for a GNU assembler and linker, and compare them with the `auto-host.h` of a
  GCC built for the target. A configure run without a target assembler and
  linker leaves `HAVE_LD_EH_FRAME_HDR` unset, which silently breaks FDE lookup.
  `ENABLE_RUNTIME_CHECKING` makes the unwinder's `gcc_assert` calls abort, as
  they do in GCC's libgcc. Sources that include `auto-host.h` directly, without
  `tconfig.h`, also see its host-only defines (the ones GCC's header puts under
  `#ifndef USED_FOR_TARGET`). Check their `#if` lines, and put each macro they
  read in that part of `_AUTO_HOST_H`, with the value from the `auto-host.h` of
  a GCC built for the target. In the x86-64 port only `config/i386/morestack.S`
  includes it directly, and it reads `HAVE_INITFINI_ARRAY_SUPPORT`. When
  `auto-host.h` lacks it, `morestack.S` registers `__stack_split_initialize` in
  `.ctors`, which compiler-rt's `crtbegin.o` does not run.
- `configure.ac.bzl`: port each `libgcc/configure.ac` check that writes
  `auto-target.h` or `INTERNAL_CFLAGS`, in configure's order, with the rules in
  `3rd_party/gcc/autoconf`. For a check that GCC's top-level `config/*.m4`
  files define, use its port in `3rd_party/gcc/gcc_config_checks.bzl`, which the
  libstdc++ port shares. Use a probe wherever configure runs one. A check that
  greps the compiler's output uses `compile_check` with `output_regex`.
  `AC_CHECK_SIZEOF` uses `ac_check_sizeof` and `AC_COMPUTE_INT` uses
  `compute_int_check`. Use policy only where configure sets the value without a
  check, or where its check does not fit this toolchain, and say why. Where the
  `configure` script GCC ships differs from the `.m4` files, follow the script,
  because it is what produces GCC's `auto-target.h`. For example, the script
  does not define `HAVE_CC_TLS`, though `config/tls.m4` does. Compare the
  rendered headers with the `auto-target.h` and `make -n` flags of a libgcc
  configured for the target.
- `__builtin_init_dwarf_reg_size_table`: compare Clang's table with GCC's
  (`xgcc -S` on a call to it) and add a shim where they differ or Clang lacks
  the builtin.

## Adding a GCC version or CPU

- A GCC version: port its differences into `makefile.bzl`, `target_config.bzl`
  and `configure.ac.bzl`, taking each value from that GCC as described above.
  Add the version to `_PORTED_VERSIONS` in `makefile.bzl` and, with its CPUs, to
  `_PORTED_TARGETS` in `target_config.bzl`. Loading fails for a version that is
  missing from them. Give each macro and substitution that the version adds a
  status in the two status files, and port the ones whose status says they are
  modeled. A `gcc=` range limits a status to the versions that have the item.
  The inventory tests name the items without a status and the statuses without
  an item. Then add the version and its CPUs to `LIBGCC_TARGETS` in
  `3rd_party/gcc/version.bzl`, and its Clang patches, if any, to
  `LIBGCC_PATCHES`. Each patch directory is named for the GCC versions its
  patches apply to without offsets. In `runtimes/libgcc/tests`, add
  `libgcc_s_<cpu>_gcc_<version>.symbols` for each CPU. Write it from a
  `libgcc_s.so.1` that GCC of the same version builds, not from the port's.
- A CPU: add its configuration and canonical triple to `target_config.bzl`, the
  tmake fragments that `config.host` selects for it to `makefile.bzl` and
  `_TMAKE_FILES`, its GCC config headers to `_LIBGCC_CPU_ARCHIVE_INCLUDES` in
  `3rd_party/gcc/extension/gcc.bzl`, the checks configure runs only for it to
  `_CPU_AUTO_TARGET_CHECKS` in `configure.ac.bzl`, and the CPU to the versions
  that build it in `LIBGCC_TARGETS`. `3rd_party/gcc/gcc.BUILD.bazel`,
  `3rd_party/gcc/extension/gcc.bzl` and `runtimes/libgcc/BUILD.bazel` follow
  `LIBGCC_TARGETS`. If its `config.host` or `config.gcc` entry reads another
  configure result, add that check to `LIBGCC_SELECTION_CHECKS`. In
  `configure_define_status.txt`, add the CPU to the CPU column of each macro
  whose check configure runs for it. In `runtimes/libgcc/tests`, add a symbol
  list for each version, and add the CPU with the programs it runs to
  `_CPU_PROGRAMS`. Those tests run on an x86-64 Linux host, so a CPU other than
  x86-64 runs its binaries under qemu-user, as AArch64 does, with a glibc for
  that CPU.

## Validation

- `bazel test //runtimes/libgcc/...` checks the exported symbols and versions
  against the symbol list of each version and CPU. It also runs exception tests,
  each linked statically and dynamically, and split-stack tests on x86-64 only,
  because `config.host` adds `t-stack`, which builds `__morestack`, only for
  x86, s390 and PowerPC. The AArch64 tests run under qemu-user.
- The configure tests (`configure_linux_<cpu>_<version>_test`) run `config.gcc`
  and `config.host` for each CPU's triple, with the `configure.ac.bzl` results
  that the CPU's toolchain probes, and compare what the scripts select with the
  port. They also compare the probed `decimal_float`, `fixed_point` and
  `HAVE_STRUB_SUPPORT` with `libgcc_makefile_conditions()`. A new GCC version
  that adds a tmake fragment, header or `tm.h` entry fails them. They do not
  check the objects inside each fragment. Only the `make -n` comparison does.
- The configure inventory tests
  (`configure_inventory_linux_<cpu>_<version>_test`) fail for a macro in
  `libgcc/config.in` or a substitution in `libgcc/Makefile.in` without a
  status, and for a status whose item GCC no longer has. They check each
  macro's status against the `auto-target.h` and `libgcc_configure_cflags.h`
  rendered for the CPU, and that the port file a modeled substitution names
  mentions it.
- For a new version or target, also run GCC's `g++.dg/eh` and
  `gcc.dg/cleanup-*` run tests, built with a GCC, against the new
  `libgcc_s.so.1` through `LD_LIBRARY_PATH` and against the static archives by
  linking with `-static-libgcc` and an `-L` path to them. For C++ tests, also
  link with `-static-libstdc++`; otherwise `libstdc++.so.6` throws through the
  system's `libgcc_s.so.1`. Every test that passes with the system libgcc must
  pass, except the tests that need decimal floating-point routines (`__bid_*`),
  which this port does not build because Clang has no decimal floating-point
  types. Build the tests with a GCC of the same version where the host has one.
  For AArch64, build them with a cross GCC, such as Ubuntu's
  `aarch64-linux-gnu-g++-10`, and run them with
  `qemu-aarch64-static -L /usr/aarch64-linux-gnu`, at `-O0` and `-O2`.
- Compare each `libgcc_s.so.1`'s exports with those of a distribution's
  `libgcc_s.so.1` built from the same GCC release, such as Ubuntu's. The system
  library may be loaded first, and the loader loads one library per soname, so
  the port must not export a symbol version that the distribution's lacks.

## Targets

x86-64 is supported for GCC 10.5.0, 14.3.0 and 17, and AArch64 for GCC 17. On
AArch64, Clang returns the frame pointer for `__builtin_dwarf_cfa` and emits
nothing for `__builtin_eh_return`, and libgcc's unwinder relies on both:

- `uw_init_context` takes the caller's CFA from `__builtin_dwarf_cfa`.
  `libgcc_clang_compat.h` maps it to `__builtin_sponentry`, the stack pointer
  at function entry, which is the CFA on AArch64.
- `uw_install_context` stores the handler's registers into its caller's save
  slots and returns through `__builtin_eh_return`.
  `libgcc-clang-aarch64-unwind.patch` loads the registers GCC's eh_return
  epilogue restores (x0-x3, x19-x30, d8-d15 and sp) from the target context
  with inline assembly and branches to the handler with `br`, as that epilogue
  does. The assembly is in the caller, `_Unwind_RaiseException` and the like,
  because a call would push a guarded control stack entry that is never popped.
  `uw_init_context_1` keeps the EH data registers x0-x3 as values, because
  without `__builtin_eh_return` the caller's frame has no save slots for them.

The AArch64 tests run their binaries under qemu-user with `rules_qemu`, and use
CentOS 8's glibc 2.28 and `libgcc_s.so.1` as the system libraries. glibc's
`pthread_exit` loads `libgcc_s.so.1` by name even when a test links the runtime
statically, so the sysroot needs one. `rules_qemu` and the CentOS 8 sysroot are
dev dependencies in `MODULE.bazel`. `3rd_party/rules_qemu` patches `rules_qemu`
0.3.0, whose extension hard-codes `root_module_direct_deps`, which Bazel
rejects when the root module uses `rules_qemu` only as a dev dependency.
