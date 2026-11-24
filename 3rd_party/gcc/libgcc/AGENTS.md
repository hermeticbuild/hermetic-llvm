# libgcc Bazel Port

This package builds libgcc (`libgcc.a`, `libgcc_eh.a`, `libgcc_s.so.1`) from
the selected GCC repository with the toolchain's Clang. The BUILD targets live
in `3rd_party/gcc/gcc.BUILD.bazel`; this package holds their data and rules.
`//runtimes/cxxstdlib` links them in place of LLVM's libunwind where
`//runtimes/libgcc:libgcc_from_gcc` matches: the GCC versions in
`LIBGCC_VERSIONS` (`3rd_party/gcc/version.bzl`) on x86-64 Linux.
`runtimes/libgcc/BUILD.bazel` also has GCC's `libgcc_s.so` linker script and
`:libgcc_library_search_directory`, where dynamic links find it with `-lgcc_s`.

## Files

- `makefile.bzl` ports the object lists of `libgcc/Makefile.in` and the tmake
  fragments `libgcc/config.host` selects. Each fragment's contribution is
  marked with its file name. Keep the fragments in config.host order, since
  later ones reassign variables.
- `target_config.bzl` holds what GCC's build directory and libgcc's configure
  would provide: `tm.h`, `tconfig.h`, the parts of `auto-host.h` that libgcc
  reads, `auto-target.h`, `libgcc_tm.h`, the `-fbuilding-libgcc` predefines,
  and shims for GCC builtins Clang lacks.
- `libgcc_rules.bzl` has the wrapper-source, hide-list and version-map rules.
- `3rd_party/gcc/patches/17.x/libgcc-clang-compat.patch` changes the spots in
  libgcc's sources that rely on GCC-only behavior, so that Clang compiles them.

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
  target.
- `auto-host.h`: set the macros as fixed policy, as GCC's configure sets them
  for a GNU assembler and linker. A configure run without a target assembler
  and linker leaves `HAVE_LD_EH_FRAME_HDR` and `TARGET_DL_ITERATE_PHDR` unset,
  which silently breaks FDE lookup. Sources that include `auto-host.h`
  directly, without `tconfig.h`, also see its host-only defines (the ones GCC's
  header puts under `#ifndef USED_FOR_TARGET`). Check their `#if` lines, and put
  each macro they read in that part of `_AUTO_HOST_H`, with the value from the
  `auto-host.h` of a GCC built for the target. In the x86-64 port only
  `config/i386/morestack.S` does this, and it reads
  `HAVE_INITFINI_ARRAY_SUPPORT`. When `auto-host.h` lacks it, `morestack.S`
  registers `__stack_split_initialize` in `.ctors`, which compiler-rt's
  `crtbegin.o` does not run.
- `__builtin_init_dwarf_reg_size_table`: compare Clang's table with GCC's
  (`xgcc -S` on a call to it) and add a shim where they differ or Clang lacks
  the builtin.

## Adding a GCC version or CPU

- A GCC version: port its differences into `makefile.bzl` and
  `target_config.bzl`, taking each value from that GCC as described above, and
  add the version to `_PORTED_VERSIONS` in both files. Loading fails for a
  version that is missing from them. Then add the version to `LIBGCC_VERSIONS`
  in `3rd_party/gcc/version.bzl`, and its Clang patches, if any, to
  `LIBGCC_PATCHES`.
- A CPU: add its configuration to `target_config.bzl`, the tmake fragments that
  `config.host` selects for it to `makefile.bzl`, and its GCC config headers to
  `_LIBGCC_ARCHIVE_INCLUDES` in `3rd_party/gcc/extension/gcc.bzl`.
  `_LIBGCC_CPU` in `3rd_party/gcc/gcc.BUILD.bazel` holds one CPU today, so the
  BUILD section has to select per CPU. Make `libgcc_from_gcc` in
  `runtimes/libgcc/BUILD.bazel` match the CPU, and add a symbol list to
  `runtimes/libgcc/tests`. Those tests run on an x86-64 Linux host, so the new
  CPU also needs a way to run them.

## Validation

- `bazel test //runtimes/libgcc/...` checks the exported symbols and versions.
  It also runs exception and split-stack tests, each linked statically and
  dynamically.
- For a new version or target, also run GCC's `g++.dg/eh` and
  `gcc.dg/cleanup-*` run tests, built with a GCC, against the new
  `libgcc_s.so.1` through `LD_LIBRARY_PATH` and against the static archives by
  linking with `-static-libgcc` and an `-L` path to them. Every test that
  passes with the system libgcc must pass, except the tests that need decimal
  floating-point routines (`__bid_*`), which this port does not build because
  Clang has no decimal floating-point types.

## Targets

Only x86-64 is supported. On AArch64, Clang emits nothing for
`__builtin_eh_return` and returns the frame pointer for `__builtin_dwarf_cfa`,
so libgcc's unwinder cannot install a handler's context. Supporting it would
most likely need a different `uw_install_context` (an assembly trampoline, as
in LLVM's libunwind) and `__builtin_sponentry` for the CFA. This has not been
tried.
