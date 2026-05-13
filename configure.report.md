# libstdc++ configure audit

This report audits the configuration decisions made by GCC libstdc++'s
`libstdc++-v3/configure.ac` and the macros it calls, especially
`libstdc++-v3/acinclude.m4`. It is intended to be a work queue for the Bazel
port, not a statement that every item must become a dynamic Bazel probe.

Sources reviewed:

- `@gcc//:libstdc++-v3/configure.ac`
- `@gcc//:libstdc++-v3/acinclude.m4`
- `@gcc//:libstdc++-v3/linkage.m4`
- `@gcc//:libstdc++-v3/configure.host`
- `@gcc//:libstdc++-v3/crossconfig.m4`
- GCC top-level config macro sources now fetched by the sparse Bazel GCC
  repository: `config/acx.m4`, `config/cet.m4`, `config/futex.m4`,
  `config/gc++filt.m4`, `config/gthr.m4`, `config/hwcaps.m4`,
  `config/iconv.m4`, `config/lthostflags.m4`, `config/multi.m4`,
  `config/no-executables.m4`, `config/tls.m4`,
  `config/toolexeclibdir.m4`, `config/unwind_ipinfo.m4`.

Legend:

- `probe`: configure compiles, links, preprocesses, runs, or checks a file/tool.
- `policy`: configure option or target decision that selects behavior.
- `substitution`: configure sets a Makefile variable, source path, flag, or
  conditional.
- `define`: configure writes a `config.h` define.
- `native`: `build == host`, or a target/host combination GCC treats as native.
- `cross`: `build != host`, except special Darwin handling.

## Top-level control flow

- Initialize package and `config.h`.
  - Source: `AC_INIT`, `AC_CONFIG_SRCDIR`, `AC_CONFIG_HEADER`.
  - Output: generated `config.h`.
  - Bazel status: replaced by `libstdcxx_config_h`.

- Enable multilib.
  - Source: `AM_ENABLE_MULTILIB(, ..)`.
  - Output: multilib configure arguments and `MULTISUBDIR` handling.
  - Bazel status: not modeled; platforms/toolchains choose target variants.

- Canonicalize build/host/target.
  - Source: `AC_CANONICAL_SYSTEM`.
  - Condition: always.
  - Output: `build`, `host`, `target`, aliases and CPU/vendor/OS pieces.
  - Bazel status: modeled by platform constraints and `configure.bzl` target
    policy.

- Decide whether executable link tests are allowed.
  - Source: direct `configure.ac` branch plus `GCC_NO_EXECUTABLES`.
  - Condition: if `build != host`, except same-version Darwin-to-Darwin cross.
  - Output: `GLIBCXX_IS_NATIVE=false`, `gcc_no_link=yes` via
    `GCC_NO_EXECUTABLES`.
  - Bazel status: partly replaced by cc-toolchain link probes. We need a clear
    policy for probes under cross execution.

- Remove `<stdio.h>` from default autoconf includes for `--without-headers`.
  - Source: direct autoconf compatibility block.
  - Condition: autoconf older than 2.70 and `with_headers=no`.
  - Output: affects autoconf generated probe includes only.
  - Bazel status: not modeled; relevant only if freestanding/no-headers support
    is added.

- Find C and C++ compilers.
  - Source: `AC_PROG_CC`, `AC_PROG_CXX`; `CXXFLAGS` temporarily includes
    `-fno-builtin`.
  - Condition: always.
  - Output: `CC`, `CXX`, compiler sanity.
  - Bazel status: cc toolchain selection replaces this.

- Large file support.
  - Source: `AC_SYS_LARGEFILE`.
  - Output: autoconf large-file defines such as `_FILE_OFFSET_BITS` when needed.
  - Bazel status: not emitted for the current supported Linux GNU libstdc++
    targets because they are 64-bit triples where large file support is the
    default ABI. `largefile-config.h` already forwards `_FILE_OFFSET_BITS`,
    `_LARGE_FILES`, and `_DARWIN_USE_64_BIT_INODE` from generated `config_h` if
    a future 32-bit or Darwin target needs them.

## GLIBCXX_CONFIGURE and GLIBCXX_CHECK_HOST

- Define libstdc++ subdirectories.
  - Source: `GLIBCXX_CONFIGURE`.
  - Output: `SUBDIRS=include libsupc++ src src/c++98 src/c++11 src/c++17
    src/c++20 src/c++23 src/c++26 src/filesystem src/libbacktrace
    src/experimental doc po testsuite python`.
  - Bazel status: source graph is manually modeled.

- Compute absolute source/build paths.
  - Source: `GLIBCXX_CONFIGURE`.
  - Output: `glibcxx_builddir`, `glibcxx_srcdir`, `toplevel_builddir`,
    `toplevel_srcdir`.
  - Bazel status: not relevant; Bazel labels/actions replace these.

- Parse top-level options.
  - Source: `GLIBCXX_CONFIGURE`.
  - Options: `--with-target-subdir`, `--with-cross-host`, `--with-newlib`,
    `--with-picolibc`.
  - Output: shell vars used later by hosted/cross/libc checks.
  - Bazel status: target platform/libc policy replaces these; picolibc/newlib
    are unsupported today.

- Find file-link and archive tools.
  - Source: `AC_PROG_LN_S`, `AC_CHECK_TOOL(AS)`, `AC_CHECK_TOOL(AR)`,
    `AC_CHECK_TOOL(RANLIB)`.
  - Output: tool vars for make/libtool.
  - Bazel status: cc toolchain and Bazel tool actions replace these.

- Detect C library flavor.
  - Source: `AC_EGREP_CPP` for `__UCLIBC__` and `__BIONIC__`.
  - Condition: always.
  - Output: `uclibc=yes/no`, `bionic=yes/no`; used by `configure.host`.
  - Bazel status: not modeled. Current support is Linux glibc only for
    libstdc++ dynamic runtime.

- Source `configure.host`.
  - Source: `GLIBCXX_CHECK_HOST`.
  - Output: target-derived directories and flags: `cpu_include_dir`,
    `os_include_dir`, `atomicity_dir`, `atomic_word_dir`, `cpu_defines_dir`,
    `error_constants_dir`, `abi_tweaks_dir`, `tmake_file`, `atomic_flags`,
    `target_thread_file`, `c_model`, and related host policy.
  - Bazel status: partially modeled in `runtimes/libstdcxx/configure.bzl`.
  - Follow-up: now exported as `@gcc//:libstdc++-v3/configure.host`; fold its
    host cases into the next audit pass instead of relying on prior local
    checkouts.

## Libtool and shared/static policy

- Configure libtool dlopen support.
  - Source: `AC_LIBTOOL_DLOPEN`.
  - Condition: not newlib, not picolibc, not avrlibc, and not `with_headers=no`.
  - Output: libtool dlopen settings.
  - Bazel status: not relevant unless building libtool-like artifacts.

- Configure libtool.
  - Source: `AM_PROG_LIBTOOL`, `ACX_LT_HOST_FLAGS`,
    `AC_SUBST(enable_shared)`, `AC_SUBST(enable_static)`.
  - Output: shared/static settings, host flags, libtool commands.
  - Bazel status: replaced by `cc_shared_library`/runtime stage rules and
    explicit dynamic-only libstdc++ scope.

- Darwin rpath and OS conditionals.
  - Source: `ENABLE_DARWIN_AT_RPATH`, `OS_IS_DARWIN`.
  - Condition: Darwin targets.
  - Output: automake conditionals.
  - Bazel status: unsupported for libstdc++ today.

- Vtable verification libgcc objects.
  - Source: direct `if test "$enable_vtable_verify" = yes`.
  - Condition: `--enable-vtable-verify`.
  - Output: appends `vtv_start.o` and `vtv_end.o`.
  - Bazel status: unsupported/default off.

- Shared-library compile flags.
  - Source: direct configure block after libtool.
  - Condition: `enable_shared=yes`.
  - Output: `glibcxx_lt_pic_flag=-prefer-pic`,
    `glibcxx_compiler_pic_flag=$lt_prog_compiler_pic_CXX`,
    `glibcxx_compiler_shared_flag=-D_GLIBCXX_SHARED`, and override of
    libtool PIC mode.
  - Bazel status: `_GLIBCXX_SHARED` is modeled through shared runtime build
    settings; PIC comes from cc toolchain/rules.

- Remove `-lstdc++` from C++ postdeps.
  - Source: direct sed on `postdeps_CXX`.
  - Condition: always after libtool.
  - Output: avoids self-linking against libstdc++ while building libstdc++.
  - Bazel status: modeled structurally by not depending on a C++ runtime for
    stage1/runtime tool builds.

## Compiler and linker capability macros

- `GLIBCXX_CHECK_COMPILER_FEATURES`
  - Condition: always.
  - Probe: C++ compile with `-g -Werror -ffunction-sections
    -fdata-sections`.
  - Output: `SECTION_FLAGS='-ffunction-sections -fdata-sections'` if accepted.
  - Bazel status: not modeled as `config.h`; build flags/toolchain decide.

- `GLIBCXX_CHECK_LINKER_FEATURES`
  - Condition: native branch and required by `GLIBCXX_ENABLE_SYMVERS`.
  - Probes:
    - GNU ld detection/version, plus gold/mold/Wild detection.
    - `--gc-sections` support.
    - linker optimization and hardening flags such as `-Wl,-O1` and relro
      where supported.
  - Outputs: `with_gnu_ld`, `glibcxx_ld_is_gold`, `glibcxx_ld_is_mold`,
    `glibcxx_ld_is_wild`, `glibcxx_gnu_ld_version`, `SECTION_LDFLAGS`,
    `OPT_LDFLAGS`.
  - Bazel status: only symbol versioning assumptions are modeled. Linker flag
    optimization policy is not modeled.

- `GCC_CHECK_ASSEMBLER_HWCAP`
  - Condition: Solaris targets only.
  - Probe: C compile with `-Wa,-nH`.
  - Output: `HWCAP_CFLAGS="-Wa,-nH"` if supported.
  - Bazel status: unsupported/not relevant for Linux glibc scope.

- `GCC_CET_FLAGS(CET_FLAGS)`
  - Condition: x86 or x86_64 Linux hosts, `--enable-cet=auto|yes`.
  - Probes:
    - Compile with `-fcf-protection`.
    - Assembler accepts `setssbsy`.
    - Requires SSE2/multibyte NOP support.
  - Output: `CET_FLAGS="-fcf-protection -mshstk"` when enabled, then appended
    to `EXTRA_CFLAGS` and `EXTRA_CXX_FLAGS`.
  - Bazel status: not modeled.

- `GCC_BASE_VER`
  - Condition: always.
  - Policy: `--with-gcc-major-version-only` changes version path from full
    `BASE-VER` to major-only.
  - Output: `get_gcc_base_ver`.
  - Bazel status: not modeled for installation paths; runtime shared object no
    longer uses full `6.0.N` real name.

## Hosted, verbosity, PCH, threads, atomics, lock policy

- `GLIBCXX_ENABLE_HOSTED`
  - Conditions:
    - Defaults off for `arm*-*-symbianelf*`.
    - Defaults off for `with_newlib=no` and `with_headers=no`.
    - Otherwise defaults on.
    - `--disable-hosted-libstdcxx` or `--disable-libstdcxx-hosted` force
      freestanding.
  - Outputs:
    - `is_hosted=yes/no`.
    - `_GLIBCXX_HOSTED` defined to `__STDC_HOSTED__` or `0`.
    - disables ABI check and PCH when freestanding.
    - `FREESTANDING_FLAGS=-ffreestanding` when freestanding and no headers.
  - Bazel status: hosted is assumed. Freestanding is not implemented.

- `GLIBCXX_ENABLE_VERBOSE`
  - Condition: `--disable-libstdcxx-verbose` toggles.
  - Output: `_GLIBCXX_VERBOSE=1|0`.
  - Bazel status: fixed/policy; should be a build setting later.

- `GLIBCXX_ENABLE_PCH`
  - Condition: default from caller and hosted status.
  - Probe: actually build a C++ precompiled header and then verify it is used.
  - Output: `GLIBCXX_BUILD_PCH` conditional and
    `glibcxx_PCHFLAGS="-include bits/stdc++.h"` if supported.
  - Bazel status: not modeled.

- `GLIBCXX_ENABLE_DECIMAL_FLOAT`
  - Condition: always.
  - Probe: C compile-only check that `_Decimal32`, `_Decimal64`, and
    `_Decimal128` are accepted.
  - Output: `_GLIBCXX_USE_DECIMAL_FLOAT`.
  - Bazel status: fixed/policy today. Needs explicit decision before claiming
    target parity.

- `GLIBCXX_ENABLE_FLOAT128`
  - Condition: always.
  - Probe: C++ compile-only check that `__float128` exists and is distinct from
    `double` and `long double`.
  - Outputs:
    - `ENABLE_FLOAT128` conditional.
    - `float128.ver` appended to `port_specific_symbol_files` when enabled.
  - Bazel status: target policy today. Needs to become a policy/probe with the
    version-script consequence modeled together.

- `GLIBCXX_ENABLE_THREADS`
  - Source: `GCC_AC_THREAD_MODEL`, `GCC_AC_THREAD_HEADER`.
  - Output: `target_thread_file`, `thread_header`.
  - Bazel status: `thread_header` modeled as `gthr-posix.h` for supported
    targets; other thread models unsupported.

- `GLIBCXX_ENABLE_ATOMIC_BUILTINS`
  - Conditions:
    - Uses link tests on Linux/uclinux/kfreebsd-gnu/GNU if linking is possible.
    - Otherwise uses assembly inspection.
  - Probe: whether `__atomic_fetch_add` on `_Atomic_word` lowers without
    libatomic dependency.
  - Outputs:
    - `_GLIBCXX_ATOMIC_WORD_BUILTINS`.
    - `atomicity_dir=cpu/generic/atomicity_builtins` on success.
    - falls back to `cpu/generic/atomicity_mutex` if generic and no builtins.
  - Bazel status: currently policy-selected to builtins. Needs semantic audit
    against GCC probe, especially for non-x86_64.

- `GLIBCXX_ENABLE_LOCK_POLICY`
  - Policy: `--with-libstdcxx-lock-policy=atomic|mutex|auto`.
  - Condition: ignored for GCC single-thread model.
  - Probe in `auto`: compile-time check for 2-byte and 4-byte
    `__GCC_HAVE_SYNC_COMPARE_AND_SWAP_*`; RISC-V intentionally errors to keep
    mutex-based ABI compatibility; AMDGCN/NVPTX force yes.
  - Output: `HAVE_ATOMIC_LOCK_POLICY`.
  - Bazel status: target-derived/policy today; needs per-target audit.

- `GLIBCXX_CHECK_GTHREADS`
  - Condition: `--enable-libstdcxx-threads=auto|yes`; after symbol versioning.
  - Probes:
    - `_GTHREAD_USE_MUTEX_TIMEDLOCK` based on `_POSIX_TIMEOUTS` for pthreads;
      forced false for Win32 thread model.
    - `gthr.h` defines `__GTHREADS_CXX0X`.
    - If pthread-backed, whether `pthread_rwlock_t` exists in `gthr.h`
      context.
  - Outputs: `_GTHREAD_USE_MUTEX_TIMEDLOCK`, `_GLIBCXX_HAS_GTHREADS`,
    `_GLIBCXX_USE_PTHREAD_RWLOCK_T`.
  - Bazel status: mostly policy/probe modeled, but should be compared against
    the exact `gthr.h` context.

## C library model, allocator, I/O, locale

- `GLIBCXX_ENABLE_CSTDIO`
  - Policy: `--enable-cstdio=stdio|stdio_posix|stdio_pure`.
  - Output:
    - `CSTDIO_H=config/io/c_io_stdio.h`.
    - `BASIC_FILE_H=config/io/basic_file_stdio.h`.
    - `BASIC_FILE_CC=config/io/basic_file_stdio.cc`.
    - `_GLIBCXX_USE_STDIO_PURE` only for `stdio_pure`.
  - Bazel status: stdio+POSIX model assumed.

- `GLIBCXX_ENABLE_CLOCALE`
  - Policy: `--enable-clocale=generic|gnu|ieee_1003.1-2001|newlib|yes|no|auto`.
  - Auto selection:
    - Linux/GNU/kfreebsd-gnu/knetbsd-gnu -> `gnu`.
    - Darwin -> `darwin`.
    - VxWorks -> `vxworks`.
    - DragonFly/FreeBSD -> `dragonfly`.
    - OpenBSD -> `newlib`.
    - `with_newlib=yes` -> `newlib`.
    - fallback -> `generic`.
  - Probes:
    - For `gnu`, verify glibc >= 2.3 and not uClibc via `<features.h>`, else
      fall back to `generic`.
    - `strxfrm_l` in `<string.h>/<locale.h>` -> `HAVE_STRXFRM_L`.
    - `strerror_l` -> `HAVE_STRERROR_L`.
    - `strerror_r` -> `HAVE_STRERROR_R`.
    - For GNU locale, `msgfmt` and `--enable-nls` decide `USE_NLS`.
    - If `USE_NLS=yes`, check `libintl.h` and search `gettext` in `intl`;
      define `_GLIBCXX_USE_NLS`.
  - Outputs: locale header/source substitutions:
    `CLOCALE_H`, `CLOCALE_CC`, `CCODECVT_CC`, `CCOLLATE_CC`, `CCTYPE_CC`,
    `CMESSAGES_H`, `CMESSAGES_CC`, `CMONEY_CC`, `CNUMERIC_CC`, `CTIME_H`,
    `CTIME_CC`, `CLOCALE_INTERNAL_H`, plus `USE_NLS`.
  - Bazel status: `gnu`/`generic` policy modeled; NLS not modeled.

- `GLIBCXX_ENABLE_ALLOCATOR`
  - Policy: `--enable-libstdcxx-allocator=new|malloc|auto`.
  - Auto selection: `new` for all listed targets.
  - Outputs: `ALLOCATOR_H`, `ALLOCATOR_NAME`, `ENABLE_ALLOCATOR_NEW`.
  - Bazel status: `new_allocator_base.h` assumed.

- `GLIBCXX_ENABLE_CHEADERS($c_model)`
  - Policy: choose C header model from `configure.host` `c_model`.
  - Outputs: C compatibility header model and related substitutions.
  - Bazel status: not separately audited yet; current header overlay assumes
    the standard GCC header layout.

## Build feature toggles that affect sources, flags, or ABI

- `GLIBCXX_ENABLE_CONCEPT_CHECKS`
  - Policy: `--enable-concept-checks`, default no in `configure.ac`.
  - Output: `_GLIBCXX_CONCEPT_CHECKS` when enabled.
  - Bazel status: unsupported/default off.

- `GLIBCXX_ENABLE_DEBUG_FLAGS`
  - Policy: `--enable-libstdcxx-debug-flags=FLAGS`, default
    `-g3 -O0 -D_GLIBCXX_ASSERTIONS`.
  - Output: `DEBUG_FLAGS`.
  - Bazel status: not modeled because separate debug libraries are not built.

- `GLIBCXX_ENABLE_DEBUG`
  - Policy: `--enable-libstdcxx-debug`, default no in `configure.ac`.
  - Condition: when enabled during GCC bootstrap, debug libraries are skipped
    except in the final stage.
  - Output: `GLIBCXX_BUILD_DEBUG` conditional.
  - Bazel status: unsupported/default off.

- `GLIBCXX_ENABLE_PARALLEL`
  - Condition: enabled only when target `libgomp` is present in
    `TARGET_CONFIGDIRS`.
  - Output: `enable_parallel=yes/no`; source graph includes or excludes
    parallel mode library pieces.
  - Bazel status: not modeled. If parallel mode sources are ever exposed, this
    should depend on a modeled OpenMP/libgomp runtime rather than a shell var.

- `GLIBCXX_ENABLE_CXX_FLAGS`
  - Policy: `--enable-cxx-flags=FLAGS`.
  - Validation: flags must be empty/no or begin with `-`.
  - Output: appends flags to `EXTRA_CXX_FLAGS`.
  - Bazel status: not modeled; user/toolchain copts replace this for now.

- `GLIBCXX_ENABLE_FULLY_DYNAMIC_STRING`
  - Policy: `--enable-fully-dynamic-string=yes|no`.
  - ABI note: enabling changes the old COW string ABI by avoiding a shared
    static empty representation.
  - Output: `_GLIBCXX_FULLY_DYNAMIC_STRING=1|0`.
  - Bazel status: default off/policy-defined. If old ABI support is exposed,
    this must be a real ABI-affecting knob.

- `GLIBCXX_ENABLE_EXTERN_TEMPLATE`
  - Policy: `--enable-extern-template=yes|no`, default yes in `configure.ac`.
  - Output: `ENABLE_EXTERN_TEMPLATE` conditional.
  - Bazel status: current source graph assumes GCC's default extern-template
    behavior.

- `GLIBCXX_ENABLE_PYTHON`
  - Policy: `--with-python-dir=DIR`.
  - Output: `python_mod_dir` and `ENABLE_PYTHONDIR` conditional for pretty
    printer install support.
  - Bazel status: install-only; not needed for runtime build.

- `GLIBCXX_ENABLE_WERROR`
  - Policy: `--enable-werror`, default no in `configure.ac`.
  - Output: `ENABLE_WERROR` conditional.
  - Bazel status: not modeled.

- `GLIBCXX_ENABLE_VTABLE_VERIFY`
  - Policy: `--enable-vtable-verify`, default no in `configure.ac`.
  - Output:
    - target-specific `VTV_CXXFLAGS` and `VTV_CXXLINKFLAGS`.
    - `VTV_CYGMIN` conditional.
    - later direct configure logic appends `vtv_start.o` and `vtv_end.o` when
      enabled.
  - Bazel status: unsupported/default off.

## C99, TR1, wchar, uchar, LFS, time

- `GLIBCXX_ENABLE_LONG_LONG`
  - Policy: `--enable-long-long`.
  - Output: `_GLIBCXX_USE_LONG_LONG`.
  - Bazel status: policy-defined.

- `GLIBCXX_ENABLE_WCHAR_T`
  - Policy: `--enable-wchar_t`.
  - Probes:
    - `<wchar.h>` and `<wctype.h>` headers.
    - `mbstate_t` -> `HAVE_MBSTATE_T`.
    - Large C++ compile importing wide APIs: `btowc`, `fgetwc`, `fgetws`,
      `fputwc`, `fputws`, `fwide`, `fwprintf`, `fwscanf`, `getwc`,
      `getwchar`, `mbrlen`, `mbrtowc`, `mbsinit`, `mbsrtowcs`, `putwc`,
      `putwchar`, `swprintf`, `swscanf`, `ungetwc`, `vfwprintf`,
      `vswprintf`, `vwprintf`, `wcrtomb`, `wcscat`, `wcschr`, `wcscmp`,
      `wcscoll`, `wcscpy`, `wcscspn`, `wcsftime`, `wcslen`, `wcsncat`,
      `wcsncmp`, `wcsncpy`, `wcspbrk`, `wcsrchr`, `wcsrtombs`, `wcsspn`,
      `wcsstr`, `wcstod`, `wcstok`, `wcstol`, `wcstoul`, `wcsxfrm`,
      `wctob`, `wmemchr`, `wmemcmp`, `wmemcpy`, `wmemmove`, `wmemset`,
      `wprintf`, `wscanf`.
  - Output: `_GLIBCXX_USE_WCHAR_T`.
  - Bazel status: modeled as compile probes. `HAVE_MBSTATE_T` is checked
    separately, and `_GLIBCXX_USE_WCHAR_T` now uses the upstream wide API
    declaration group.

- `GLIBCXX_ENABLE_C99`
  - Policy: `--enable-c99` default yes.
  - Conditions:
    - Uses C++98 mode first, then C++11 mode.
    - Uses link tests with `-lm` when possible, else compile-only.
  - C++98 probes and outputs:
    - C99 generic macros in `<math.h>` -> `_GLIBCXX98_USE_C99_MATH`.
    - `<tgmath.h>` and `<complex.h>` headers.
    - C99 complex functions `cabs*`, `carg*`, `ccos*`, `ccosh*`, `cexp*`,
      `clog*`, `csin*`, `csinh*`, `csqrt*`, `ctan*`, `ctanh*`, `cpow*`,
      `cproj*` -> `_GLIBCXX98_USE_C99_COMPLEX`.
    - `vfscanf`, `vscanf`, `vsnprintf`, `vsscanf`, `snprintf` ->
      `_GLIBCXX98_USE_C99_STDIO`.
    - `strtof`, `strtold`, `strtoll`, `strtoull`, `llabs`, `lldiv`, `atoll`,
      `_Exit` -> `_GLIBCXX98_USE_C99_STDLIB`.
    - `wcstold`, `wcstoll`, `wcstoull` -> `_GLIBCXX98_USE_C99_WCHAR`.
    - Optional wide functions -> `HAVE_VFWSCANF`, `HAVE_VSWSCANF`,
      `HAVE_VWSCANF`, `HAVE_WCSTOF`, `HAVE_ISWBLANK`.
    - If all C++98 groups pass -> `_GLIBCXX_USE_C99`.
  - C++11 probes and outputs:
    - `<stdint.h>` complete integer typedefs/macros ->
      `_GLIBCXX_USE_C99_STDINT`.
    - `<inttypes.h>` `imaxabs`, `imaxdiv`, `strtoimax`, `strtoumax` ->
      `_GLIBCXX_USE_C99_INTTYPES`.
    - `<inttypes.h>` `wcstoimax`, `wcstoumax` ->
      `_GLIBCXX_USE_C99_INTTYPES_WCHAR_T`.
    - C99 generic math macros -> `_GLIBCXX11_USE_C99_MATH`.
    - `float_t` and `double_t` -> `HAVE_C99_FLT_EVAL_TYPES`.
    - C99 math function group -> `_GLIBCXX_USE_C99_MATH_FUNCS`.
    - Darwin-only missing `llrint`/`llround` group ->
      `_GLIBCXX_NO_C99_ROUNDING_FUNCS`.
    - C99 complex function group -> `_GLIBCXX11_USE_C99_COMPLEX`.
    - Complex inverse trig group -> `_GLIBCXX_USE_C99_COMPLEX_ARC`.
    - C99 stdio group -> `_GLIBCXX11_USE_C99_STDIO`.
    - C99 stdlib group -> `_GLIBCXX11_USE_C99_STDLIB`.
    - C99 wchar group -> `_GLIBCXX11_USE_C99_WCHAR`.
    - `isblank` in `<ctype.h>` -> `_GLIBCXX_USE_C99_CTYPE`.
    - Full `<fenv.h>` group -> `_GLIBCXX_USE_C99_FENV`.
  - Bazel status: modeled as compile or link probes for the active Linux GNU
    configuration. The probe groups intentionally follow the upstream C++98 and
    C++11 split.

- `GLIBCXX_CHECK_C99_TR1`
  - Condition: always after C99 enablement, with C++98 mode.
  - Probes and outputs:
    - `<complex.h>` inverse trig group -> `_GLIBCXX_USE_C99_COMPLEX_TR1`.
    - `isblank` in `<ctype.h>` -> `_GLIBCXX_USE_C99_CTYPE_TR1`.
    - full `<fenv.h>` group -> `_GLIBCXX_USE_C99_FENV_TR1`.
    - complete `<stdint.h>` integer typedefs/macros ->
      `_GLIBCXX_USE_C99_STDINT_TR1`.
    - large C99 `<math.h>` function group -> `_GLIBCXX_USE_C99_MATH_TR1`.
    - `<inttypes.h>` `imaxabs`, `imaxdiv`, `strtoimax`, `strtoumax` ->
      `_GLIBCXX_USE_C99_INTTYPES_TR1`.
    - `<inttypes.h>` `wcstoimax`, `wcstoumax` ->
      `_GLIBCXX_USE_C99_INTTYPES_WCHAR_T_TR1`.
    - `stdbool.h` and `stdalign.h` header checks.
  - Bazel status: modeled as compile probes for the active Linux GNU
    configuration.

- `GLIBCXX_CHECK_UCHAR_H`
  - Probes:
    - `<uchar.h>`.
    - C++11 `c16rtomb`, `c32rtomb`, `mbrtoc16`, `mbrtoc32` plus UTF macros ->
      `_GLIBCXX_USE_C11_UCHAR_CXX11`.
    - `-fchar8_t` `c8rtomb`, `mbrtoc8` ->
      `_GLIBCXX_USE_UCHAR_C8RTOMB_MBRTOC8_FCHAR8_T`.
    - C++20 `c8rtomb`, `mbrtoc8` ->
      `_GLIBCXX_USE_UCHAR_C8RTOMB_MBRTOC8_CXX20`.
  - Bazel status: modeled as compile probes.

- `GLIBCXX_CHECK_LFS`
  - Probes:
    - LFS group: `fopen64`, `fseeko64`, `ftello64`, `lseek64`, `stat64`,
      `fstat64` -> `_GLIBCXX_USE_LFS`.
    - POSIX group: `fseeko`, `ftello` -> `_GLIBCXX_USE_FSEEKO_FTELLO`.
  - Bazel status: modeled. `_GLIBCXX_USE_LFS` uses the full upstream function
    group.

- `GLIBCXX_CHECK_GETTIMEOFDAY`
  - Condition: hosted C++ with `-fno-exceptions`.
  - Probe: `<sys/time.h>` and `gettimeofday`.
  - Output: `_GLIBCXX_USE_GETTIMEOFDAY`.
  - Bazel status: modeled.

- `GLIBCXX_ENABLE_LIBSTDCXX_TIME`
  - Policy: `--enable-libstdcxx-time=auto|yes|rt|no`.
  - Auto target policy:
    - Cygwin -> `nanosleep`.
    - MinGW -> Win32 `Sleep` and `sched_yield`.
    - Darwin/VxWorks -> `nanosleep`, Darwin also `sched_yield`.
    - Linux/GNU/kfreebsd-gnu/knetbsd-gnu -> if hosted, search `clock_gettime`
      in libc/rt; always assume `nanosleep` and `sched_yield`.
    - FreeBSD/NetBSD/DragonFly/RTEMS/Solaris -> monotonic, realtime,
      nanosleep, sched_yield.
    - OpenBSD -> monotonic, realtime, nanosleep.
    - uClinux -> nanosleep, sched_yield.
  - Non-auto probes:
    - `clock_gettime`, `nanosleep`, optionally with `-lrt`.
    - `sched_yield`, optionally with `-lrt`.
    - `<unistd.h>`, POSIX timer macro gates, monotonic/realtime clocks.
  - Linux fallback:
    - If no monotonic clock, compile direct `syscall(SYS_clock_gettime, ...)`.
    - Check `timespec` compatibility with `SYS_clock_gettime` vs
      `SYS_clock_gettime64`.
  - Outputs: `_GLIBCXX_USE_CLOCK_MONOTONIC`,
    `_GLIBCXX_USE_CLOCK_REALTIME`, `_GLIBCXX_USE_SCHED_YIELD`,
    `_GLIBCXX_USE_NANOSLEEP`, `_GLIBCXX_USE_WIN32_SLEEP`, `HAVE_SLEEP`,
    `HAVE_USLEEP`, `_GLIBCXX_NO_SLEEP`, `_GLIBCXX_USE_CLOCK_GETTIME_SYSCALL`,
    `GLIBCXX_LIBS`.
  - Bazel status: most Linux path values are modeled; syscall fallback and
    exact `timespec` compatibility are not.

## Header/function checks outside aggregate macros

- `GLIBCXX_CHECK_STDIO_PROTO`
  - Probe: C++11 `<stdio.h>` `gets`.
  - Output: `HAVE_GETS`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_MATH11_PROTO`
  - Conditions:
    - Solaris: special C++11 `<math.h>` overload checks.
    - Other targets: obsolete `isinf(double)` and `isnan(double)` checks.
  - Outputs: `__CORRECT_ISO_CPP11_MATH_H_PROTO_FP`,
    `__CORRECT_ISO_CPP11_MATH_H_PROTO_INT`, `HAVE_OBSOLETE_ISINF`,
    `HAVE_OBSOLETE_ISNAN`.
  - Bazel status: obsolete checks modeled; Solaris-only defines unsupported.

- `AC_CHECK_HEADERS(sys/ioctl.h sys/filio.h)`
  - Output: `HAVE_SYS_IOCTL_H`, `HAVE_SYS_FILIO_H`.
  - Bazel status: header probe list.

- `GLIBCXX_CHECK_POLL`
  - Probe: `<poll.h>` and `poll`.
  - Output: `HAVE_POLL`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_S_ISREG_OR_S_IFREG`
  - Probe: `<sys/stat.h>` `S_ISREG`, else `S_IFREG`.
  - Outputs: `HAVE_S_ISREG`, `HAVE_S_IFREG`.
  - Bazel status: modeled.

- `AC_CHECK_HEADERS(sys/uio.h)` and `GLIBCXX_CHECK_WRITEV`
  - Probe: `<sys/uio.h>` and `writev`.
  - Outputs: `HAVE_SYS_UIO_H`, `HAVE_WRITEV`.
  - Bazel status: modeled.

- `AC_CHECK_HEADERS(fenv.h complex.h)`
  - Condition: before `GLIBCXX_CHECK_C99_TR1`, intentionally with C compiler.
  - Outputs: `HAVE_FENV_H`, `HAVE_COMPLEX_H`.
  - Bazel status: header probe list.

- `GLIBCXX_COMPUTE_STDIO_INTEGER_CONSTANTS`
  - Condition: hosted.
  - Probes: compute `EOF`, `SEEK_CUR`, `SEEK_END`.
  - Outputs: `_GLIBCXX_STDIO_EOF`, `_GLIBCXX_STDIO_SEEK_CUR`,
    `_GLIBCXX_STDIO_SEEK_END`.
  - Bazel status: policy-defined to glibc values.

- `GLIBCXX_CHECK_TMPNAM`
  - Probe: C++ `<stdio.h>` `tmpnam`.
  - Output: `_GLIBCXX_USE_TMPNAM`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_PTHREAD_COND_CLOCKWAIT`
  - Probe: `<pthread.h>` `pthread_cond_clockwait`.
  - Output: `_GLIBCXX_USE_PTHREAD_COND_CLOCKWAIT`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_PTHREAD_MUTEX_CLOCKLOCK`
  - Probe: `<pthread.h>` `pthread_mutex_clocklock`.
  - Output: `_GLIBCXX_USE_PTHREAD_MUTEX_CLOCKLOCK`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_PTHREAD_RWLOCK_CLOCKLOCK`
  - Probe: `<pthread.h>` `pthread_rwlock_clockrdlock` and
    `pthread_rwlock_clockwrlock`.
  - Output: `_GLIBCXX_USE_PTHREAD_RWLOCK_CLOCKLOCK`.
  - Bazel status: modeled.

- `AC_LC_MESSAGES`
  - Probe: `<locale.h>` and `LC_MESSAGES`.
  - Output: `HAVE_LC_MESSAGES`.
  - Bazel status: modeled.

- Hardware concurrency checks.
  - `AC_CHECK_HEADERS(sys/sysinfo.h)` -> `HAVE_SYS_SYSINFO_H`.
  - `GLIBCXX_CHECK_GET_NPROCS` -> `_GLIBCXX_USE_GET_NPROCS`.
  - `AC_CHECK_HEADERS(unistd.h)` -> `HAVE_UNISTD_H`.
  - `GLIBCXX_CHECK_SC_NPROCESSORS_ONLN` ->
    `_GLIBCXX_USE_SC_NPROCESSORS_ONLN`.
  - `GLIBCXX_CHECK_SC_NPROC_ONLN` -> `_GLIBCXX_USE_SC_NPROC_ONLN`.
  - `GLIBCXX_CHECK_PTHREADS_NUM_PROCESSORS_NP` ->
    `_GLIBCXX_USE_PTHREADS_NUM_PROCESSORS_NP`.
  - `GLIBCXX_CHECK_SYSCTL_HW_NCPU` -> `_GLIBCXX_USE_SYSCTL_HW_NCPU`.
  - `GLIBCXX_CHECK_SDT_H` -> `HAVE_SYS_SDT_H`.
  - Bazel status: Linux/glibc checks mostly modeled; sysctl path unsupported.

- General header checks.
  - Headers: `endian.h`, `execinfo.h`, `float.h`, `fp.h`, `ieeefp.h`,
    `inttypes.h`, `locale.h`, `machine/endian.h`, `machine/param.h`, `nan.h`,
    `stdint.h`, `stdlib.h`, `string.h`, `strings.h`, `sys/ipc.h`,
    `sys/isa_defs.h`, `sys/machine.h`, `sys/param.h`, `sys/resource.h`,
    `sys/sem.h`, `sys/stat.h`, `sys/time.h`, `sys/types.h`, `unistd.h`,
    `wchar.h`, `wctype.h`, `linux/types.h`, `linux/random.h`, `xlocale.h`.
  - Bazel status: most are in `_HEADER_CHECKS`; verify exact dependency of
    `linux/random.h` on `linux/types.h`.

## Native-only branch

Condition: `GLIBCXX_IS_NATIVE=true`.

- `GLIBCXX_CHECK_LINKER_FEATURES`
  - Covered above.

- `GLIBCXX_CHECK_MATH_SUPPORT`
  - Probes math library functions and defines many `HAVE_*` math functions.
  - Outputs include float, double, and long-double variants such as
    `HAVE_ACOSF`, `HAVE_ACOSL`, `HAVE_ASINF`, `HAVE_ASINL`, `HAVE_ATAN2F`,
    `HAVE_ATAN2L`, `HAVE_ATANF`, `HAVE_ATANL`, `HAVE_CEILF`, `HAVE_CEILL`,
    `HAVE_COSF`, `HAVE_COSHF`, `HAVE_COSHL`, `HAVE_COSL`, `HAVE_EXPF`,
    `HAVE_EXPL`, `HAVE_FABSF`, `HAVE_FABSL`, `HAVE_FINITE`, `HAVE_FINITEF`,
    `HAVE_FINITEL`, `HAVE_FLOORF`, `HAVE_FLOORL`, `HAVE_FMODF`,
    `HAVE_FMODL`, `HAVE_FREXPF`, `HAVE_FREXPL`, `HAVE_HYPOT`,
    `HAVE_HYPOTF`, `HAVE_HYPOTL`, `HAVE_ISINF`, `HAVE_ISINFF`,
    `HAVE_ISINFL`, `HAVE_ISNAN`, `HAVE_ISNANF`, `HAVE_ISNANL`,
    `HAVE_LDEXPF`, `HAVE_LDEXPL`, `HAVE_LOG10F`, `HAVE_LOG10L`,
    `HAVE_LOGF`, `HAVE_LOGL`, `HAVE_MODF`, `HAVE_MODFF`, `HAVE_MODFL`,
    `HAVE_FPCLASS`, `HAVE_QFPCLASS`, `HAVE_POWF`, `HAVE_POWL`,
    `HAVE_SINCOS`, `HAVE_SINCOSF`,
    `HAVE_SINCOSL`, `HAVE_SINF`, `HAVE_SINHF`, `HAVE_SINHL`, `HAVE_SINL`,
    `HAVE_SQRTF`, `HAVE_SQRTL`, `HAVE_TANF`, `HAVE_TANHF`, `HAVE_TANHL`,
    `HAVE_TANL`.
  - Bazel status: modeled as individual math link probes. `linkage.m4`
    declares some of these through helper macros; those helpers are tracked in
    `config_macro_status.txt` and represented by `gcc_check_math_support()`.

- `GLIBCXX_CHECK_STDLIB_SUPPORT`
  - Probes standard library allocation/conversion/termination functions.
  - Outputs include `HAVE_STRTOF`, `HAVE_STRTOLD`, `HAVE_ALIGNED_ALLOC`,
    `HAVE_POSIX_MEMALIGN`, `HAVE_MEMALIGN`, `HAVE__ALIGNED_MALLOC`,
    `HAVE_AT_QUICK_EXIT`, `HAVE_QUICK_EXIT`, `HAVE_SETENV`,
    `HAVE_SECURE_GETENV`, `HAVE_TIMESPEC_GET`.
  - Bazel status: modeled. `linkage.m4` helper macros are tracked in
    `config_macro_status.txt` and represented by `gcc_check_stdlib_support()`.

- `GLIBCXX_CHECK_DEV_RANDOM`
  - Probe: readable `/dev/random` and `/dev/urandom`; disables for MinGW
    false positives.
  - Outputs: `_GLIBCXX_USE_DEV_RANDOM`, `_GLIBCXX_USE_RANDOM_TR1`.
  - Bazel status: policy-defined for Linux; no filesystem probe.

- `GCC_CHECK_TLS`
  - Probe: compiler/runtime TLS support.
  - Output: `HAVE_TLS`.
  - Bazel status: modeled as compile/link TLS check.

- Native `AC_CHECK_FUNCS`
  - Functions: `__cxa_thread_atexit_impl`, `__cxa_thread_atexit`,
    `aligned_alloc`, `posix_memalign`, `memalign`, `_aligned_malloc`,
    `_wfopen`, `secure_getenv`, `timespec_get`, `sockatmark`, `uselocale`.
  - Bazel status: mostly modeled as link checks.

- `AM_ICONV`
  - Probe: iconv headers/libs.
  - Output: `HAVE_ICONV` and iconv library variables.
  - Bazel status: modeled as a link check without separate lib search.

## Cross branch

Condition: `GLIBCXX_IS_NATIVE=false`.

- Canadian cross detection.
  - Condition: `with_cross_host` set and build/cross host/target differ.
  - Output: `CANADIAN=yes/no`.
  - Bazel status: not modeled.

- Newlib branch.
  - Condition: `with_newlib=yes`.
  - Outputs:
    - `os_include_dir=os/newlib`.
    - Defines `HAVE_HYPOT`, `HAVE_STRTOF`, float math group
      `HAVE_ACOSF` through `HAVE_TANHF`, and `HAVE_MEMALIGN`.
    - Probes long-double math declarations.
    - Probes `<newlib.h>` `_ICONV_ENABLED` -> `HAVE_ICONV`.
  - RTEMS subcase:
    - Usually defines `HAVE_TLS`, except target CPUs `bfin`, `lm32`, `mips`,
      `moxie`, `or1k`, `v850`.
    - Defines `HAVE_ALIGNED_ALLOC`, `HAVE_AT_QUICK_EXIT`, `HAVE_LINK`,
      `HAVE_SYS_STAT_H`, `HAVE_SYS_TYPES_H`, `HAVE_QUICK_EXIT`,
      `HAVE_READLINK`, `HAVE_SETENV`, `HAVE_SLEEP`, `HAVE_SOCKATMARK`,
      `HAVE_STRERROR_L`, `HAVE_SYMLINK`, `HAVE_S_ISREG`, `HAVE_TRUNCATE`,
      `HAVE_UNISTD_H`, `HAVE_UNLINKAT`, `HAVE_USLEEP`,
      `_GLIBCXX_USE_CHMOD`, `_GLIBCXX_USE_MKDIR`, `_GLIBCXX_USE_CHDIR`,
      `_GLIBCXX_USE_GETCWD`, `_GLIBCXX_USE_UTIME`.
  - Bazel status: unsupported.

- Picolibc branch.
  - Condition: `with_picolibc=yes`.
  - Outputs:
    - `os_include_dir=os/picolibc`.
    - Same base float math group and `HAVE_STRTOF`, `HAVE_HYPOT`,
      `HAVE_MEMALIGN`.
    - Probes `<picolibc.h>` `_ICONV_ENABLED` -> `HAVE_ICONV`.
    - Probes `<picolibc.h>` `__THREAD_LOCAL_STORAGE` -> `HAVE_TLS`.
    - Defines `HAVE_ALIGNED_ALLOC`, `HAVE_AT_QUICK_EXIT`, `HAVE_LINK`,
      `HAVE_SYS_STAT_H`, `HAVE_SYS_TYPES_H`, `HAVE_SETENV`,
      `HAVE_STRERROR_L`, `HAVE_S_ISREG`, `HAVE_UNISTD_H`.
  - Bazel status: unsupported.

- `GLIBCXX_CROSSCONFIG`
  - Condition: cross, not newlib/picolibc, and `with_headers != no`.
  - Output: target/libc hardcoded cross defines.
  - Bazel status: now exported as `@gcc//:libstdc++-v3/crossconfig.m4`; needs
    explicit audit before expanding non-glibc support.

- Cross long-double math fallback.
  - Condition: `long_double_math_on_this_cpu=yes`.
  - Outputs: long-double math defines such as `HAVE_ACOSL`, `HAVE_ASINL`,
    `HAVE_ATAN2L`, `HAVE_ATANL`, `HAVE_CEILL`, `HAVE_COSL`, `HAVE_COSHL`,
    `HAVE_EXPL`, `HAVE_FABSL`, `HAVE_FLOORL`, `HAVE_FMODL`, `HAVE_FREXPL`,
    `HAVE_LDEXPL`, `HAVE_LOG10L`, `HAVE_LOGL`, `HAVE_MODFL`, `HAVE_POWL`,
    `HAVE_SINCOSL`, `HAVE_SINL`, `HAVE_SINHL`, `HAVE_SQRTL`, `HAVE_TANL`,
    `HAVE_TANHL`.
  - Bazel status: currently probed directly.

## Unwind, futex, symbol versions, visibility, ABI

- `GCC_CHECK_UNWIND_GETIPINFO`
  - Policy/probe substitute:
    - `--with-system-libunwind` default yes only for `ia64-*-hpux*`, else no.
    - If using system libunwind: `ia64-*-*` -> no, otherwise yes.
    - If not using system libunwind: Darwin 3 through 8 -> no, otherwise yes.
  - Output: `HAVE_GETIPINFO` for `_Unwind_GetIPInfo`.
  - Bazel status: modeled by GCC target policy for the supported Linux GNU
    configuration; the previous unrelated `getaddrinfo` probe has been
    removed.

- `GCC_LINUX_FUTEX`
  - Policy: `--enable-linux-futex=default|yes|no`.
  - Condition: Linux/uClinux targets only.
  - Default probes:
    - Link `syscall(SYS_gettid)` and `syscall(SYS_futex, ...)`.
    - Then try `pthread_tryjoin_np` with `-lpthread`.
    - If not cross-compiling, warn if `getconf GNU_LIBPTHREAD_VERSION` is not
      NPTL.
  - Explicit yes: require the syscall link test.
  - Output: caller defines `HAVE_LINUX_FUTEX`.
  - Bazel status: modeled as a simpler futex syscall link check.

- `GLIBCXX_ENABLE_SYMVERS`
  - Policy: `--enable-symvers=yes|no|gnu|gnu-versioned-namespace|darwin|darwin-export|sun`.
  - Conditions:
    - Requires linker feature knowledge and GNU `c++filt` for Sun.
    - `yes` maps to `gnu` for GNU ld except HP-UX, `darwin` on Darwin, `sun`
      on Solaris with GNU `c++filt`, otherwise no.
    - Disabled if shared libraries are off, no linker, `gcc_no_link=yes`, no
      shared libgcc, non-GNU linker for GNU style, or GNU ld too old.
  - Probes:
    - Link with `-lgcc_s`, or infer libgcc_s suffix via compiler `-v`.
    - GNU ld version >= 2.14 unless gold/mold/Wild.
    - Assembler `.symver` directive support.
    - Size and ptrdiff ABI probes: `__SIZE_TYPE__` as unsigned int and
      `__PTRDIFF_TYPE__` as int.
  - Outputs:
    - `libtool_VERSION=6:35:0` normally, `8:0:0` for
      gnu-versioned-namespace.
    - `SYMVER_FILE=config/abi/pre/none.ver|gnu.ver|gnu-versioned-namespace.ver`.
    - `_GLIBCXX_SYMVER`, `_GLIBCXX_SYMVER_GNU`,
      `_GLIBCXX_SYMVER_GNU_NAMESPACE`, `_GLIBCXX_SYMVER_DARWIN`,
      `_GLIBCXX_SYMVER_SUN`.
    - `HAVE_AS_SYMVER_DIRECTIVE`.
    - `HAVE_SYMVER_SYMBOL_RENAMING_RUNTIME_SUPPORT` except Solaris.
    - `_GLIBCXX_SIZE_T_IS_UINT`, `_GLIBCXX_PTRDIFF_T_IS_INT`.
  - Bazel status: Linux GNU style is modeled by policy; size/ptrdiff are
    currently defaulted off and should be checked per target if 32-bit targets
    are added.

- `GLIBCXX_ENABLE_LIBSTDCXX_VISIBILITY`
  - Policy: `--enable-libstdcxx-visibility=yes|no`.
  - Probe: compile hidden visibility attribute with `-Werror`.
  - Output: `ENABLE_VISIBILITY` conditional.
  - Bazel status: modeled as policy `have_attribute_visibility`.

- `GLIBCXX_ENABLE_LIBSTDCXX_DUAL_ABI`
  - Policy: `--enable-libstdcxx-dual-abi=yes|no`.
  - Condition: forced off when `enable_symvers=gnu-versioned-namespace`.
  - Output: `_GLIBCXX_USE_DUAL_ABI=1|0`.
  - Bazel status: modeled as policy.

- `GLIBCXX_DEFAULT_ABI`
  - Policy: default ABI choice.
  - Condition: `--with-default-libstdcxx-abi=gcc4-compatible|new` is only
    parsed when dual ABI is enabled; if dual ABI is disabled the default is
    forced to `gcc4-compatible`.
  - Outputs: `_GLIBCXX_USE_CXX11_ABI=1|0`,
    `ENABLE_CXX11_ABI` conditional, `glibcxx_cxx98_abi` substitution.
  - Bazel status: modeled as policy.

- Long-double compatibility.
  - Condition: `powerpc*-*-linux*`, `sparc*-*-linux*`, `s390*-*-linux*`,
    `alpha*-*-linux*`.
  - Probes:
    - `__LONG_DOUBLE_128__` and non-64-bit sparc need.
    - For PowerPC, libm `__frexpieee128`.
    - Compiler default `__LONG_DOUBLE_IEEE128__`.
  - Outputs:
    - `_GLIBCXX_LONG_DOUBLE_COMPAT`.
    - `_GLIBCXX_LONG_DOUBLE_ALT128_COMPAT`.
    - `LONG_DOUBLE_COMPAT_FLAGS`, `LONG_DOUBLE_128_FLAGS`,
      `LONG_DOUBLE_ALT128_COMPAT_FLAGS`.
    - Adds `ldbl-extra.ver` and possibly `ldbl-ieee128-extra.ver`.
  - Bazel status: intentionally defaulted off today; needs s390x review.

- `GLIBCXX_CHECK_X86_RDRAND`
  - Probe: assembler accepts `rdrand`, compiler builtin
    `__builtin_ia32_rdrand32_step`.
  - Output: `_GLIBCXX_X86_RDRAND`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_X86_RDSEED`
  - Probe: assembler accepts `rdseed`, compiler builtin
    `__builtin_ia32_rdseed_si_step`.
  - Output: `_GLIBCXX_X86_RDSEED`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_GETENTROPY`
  - Probe: `<unistd.h>` `getentropy`.
  - Output: `HAVE_GETENTROPY`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_ARC4RANDOM`
  - Probe: `<stdlib.h>` `arc4random`.
  - Output: `HAVE_ARC4RANDOM`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_EXCEPTION_PTR_SYMVER`
  - Condition: after symbol versioning.
  - Output: `HAVE_EXCEPTION_PTR_SINCE_GCC46` when symbol compatibility baseline
    indicates `std::exception_ptr` symbols exist since GCC 4.6.
  - Bazel status: policy-defined for GNU symvers.

## Filesystem, networking, backtrace, diagnostics, chrono/tzdb

- `AC_CHECK_HEADERS(fcntl.h dirent.h sys/statvfs.h utime.h)`
  - Output: header defines for Filesystem TS prerequisites.
  - Bazel status: header probe list.

- `GLIBCXX_ENABLE_FILESYSTEM_TS`
  - Policy: enable Filesystem TS build.
  - Output: automake conditionals/source selection.
  - Bazel status: source graph manually includes filesystem sources.

- `GLIBCXX_CHECK_FILESYSTEM_DEPS`
  - Probes and outputs:
    - `struct dirent::d_type` -> `HAVE_STRUCT_DIRENT_D_TYPE`.
    - `chmod` -> `_GLIBCXX_USE_CHMOD`.
    - `mkdir` -> `_GLIBCXX_USE_MKDIR`.
    - `chdir` -> `_GLIBCXX_USE_CHDIR`.
    - `getcwd` -> `_GLIBCXX_USE_GETCWD`.
    - `realpath` with XSI/PATH_MAX logic -> `_GLIBCXX_USE_REALPATH`.
    - `utimensat` with `UTIME_OMIT` and `AT_FDCWD` ->
      `_GLIBCXX_USE_UTIMENSAT`.
    - `utime` -> `_GLIBCXX_USE_UTIME`.
    - `lstat` -> `_GLIBCXX_USE_LSTAT`.
    - `struct stat::st_mtim` -> `_GLIBCXX_USE_ST_MTIM`.
    - `fchmod` -> `_GLIBCXX_USE_FCHMOD`.
    - `fchmodat` -> `_GLIBCXX_USE_FCHMODAT`.
    - `link` -> `HAVE_LINK`.
    - `lseek` -> `HAVE_LSEEK`.
    - `readlink` -> `HAVE_READLINK`.
    - `symlink` -> `HAVE_SYMLINK`.
    - `truncate` -> `HAVE_TRUNCATE`.
    - `copy_file_range` -> `_GLIBCXX_USE_COPY_FILE_RANGE`.
    - `sendfile` -> `_GLIBCXX_USE_SENDFILE`.
    - `fdopendir` -> `HAVE_FDOPENDIR`.
    - `dirfd` -> `HAVE_DIRFD`.
    - `openat` -> `HAVE_OPENAT`.
    - `unlinkat` -> `HAVE_UNLINKAT`.
  - Bazel status: modeled.

- Networking TS headers and declarations.
  - Headers: `fcntl.h`, `sys/ioctl.h`, `sys/socket.h`, `sys/uio.h`, `poll.h`,
    `netdb.h`, `arpa/inet.h`, `netinet/in.h`, `netinet/tcp.h`.
  - Declarations: `F_GETFL`, `F_SETFL`; if both exist, check `O_NONBLOCK`.
  - Output: `HAVE_O_NONBLOCK`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_SIZE_T_MANGLING`
  - Probe: C++ ABI mangling of `size_t`.
  - Output: `_GLIBCXX_MANGLE_SIZE_T`.
  - Bazel status: policy-defined as `m`; should be per-target if non-LP64/LLP64
    support grows.

- `GLIBCXX_ENABLE_BACKTRACE`
  - Policy: `--enable-libstdcxx-backtrace=auto|yes|no`.
  - Probes:
    - Atomic/sync functions for libbacktrace CPP flags.
    - `<link.h>` and `dl_iterate_phdr`.
    - Windows headers `windows.h`, `tlhelp32.h`.
    - `fcntl`.
    - declaration `strnlen`.
    - `getexecname`.
    - Compile object and classify file type with `libbacktrace/filetype.awk`;
      selects `elf.lo`, `pecoff.lo`, or `unknown.lo`.
    - ELF size 32/64.
    - If enabled, check `<sys/mman.h>` and `MAP_ANONYMOUS`/`MAP_ANON` to
      select `mmapio.lo` vs `read.lo`, and `mmap.lo` vs `alloc.lo`.
    - Uses gthreads availability for thread support.
  - Outputs:
    - `HAVE_STACKTRACE`.
    - `BACKTRACE_CPPFLAGS`, `FORMAT_FILE`, `VIEW_FILE`, `ALLOC_FILE`.
    - `BACKTRACE_SUPPORTED`, `BACKTRACE_USES_MALLOC`,
      `BACKTRACE_SUPPORTS_THREADS`.
  - Bazel status: unsupported.

- `GLIBCXX_EMERGENCY_EH_ALLOC`
  - Policy:
    - `--enable-libstdcxx-static-eh-pool`.
    - `--with-libstdcxx-eh-pool-obj-count=N`.
  - Outputs:
    - `_GLIBCXX_EH_POOL_STATIC` as compile flag.
    - `_GLIBCXX_EH_POOL_NOBJS=N` as compile flag.
    - `EH_POOL_FLAGS`.
  - Bazel status: not modeled.

- `GLIBCXX_ZONEINFO_DIR`
  - Policy: `--with-libstdcxx-zoneinfo=yes|no|static|DIR|DIR,static`.
  - Default target policy:
    - GNU/Linux/kfreebsd-gnu/knetbsd-gnu -> `/usr/share/zoneinfo`.
    - AIX, Darwin 2, others -> no filesystem directory by default.
    - Embed static tzdata by default when pointer width is at least 32.
  - Native check: warn if configured directory lacks `tzdata.zi`.
  - Outputs: `_GLIBCXX_ZONEINFO_DIR`, `_GLIBCXX_STATIC_TZDATA`,
    `USE_STATIC_TZDATA`.
  - Bazel status: directory policy modeled as `/usr/share/zoneinfo`; static
    tzdata not modeled.

- `GLIBCXX_STRUCT_TM_TM_ZONE`
  - Probe: C++20 `<time.h>` `struct tm::tm_zone`.
  - Output: `_GLIBCXX_USE_STRUCT_TM_TM_ZONE`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_ALIGNAS_CACHELINE`
  - Probe: align static object to `__GCC_DESTRUCTIVE_SIZE`.
  - Output: `_GLIBCXX_CAN_ALIGNAS_DESTRUCTIVE_SIZE`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_INIT_PRIORITY`
  - Probe: `__has_attribute(init_priority)`.
  - Output: `_GLIBCXX_USE_INIT_PRIORITY_ATTRIBUTE`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_FILEBUF_NATIVE_HANDLES`
  - Condition: meaningful on Windows.
  - Probe: `_get_osfhandle` in `<io.h>`.
  - Output: `_GLIBCXX_USE__GET_OSFHANDLE`.
  - Bazel status: unsupported; libstdc++ Windows unsupported.

- `GLIBCXX_CHECK_TEXT_ENCODING`
  - Probe: `newlocale`, `nl_langinfo_l(CODESET, loc)`, `freelocale`.
  - Output: `_GLIBCXX_USE_NL_LANGINFO_L`.
  - Bazel status: modeled.

- `GLIBCXX_CHECK_DEBUGGING`
  - Headers: `sys/ptrace.h`, `debugapi.h`.
  - Policy: Linux targets define `_GLIBCXX_USE_PROC_SELF_STATUS`.
  - Probe: `ptrace(PTRACE_TRACEME, ...)`.
  - Output: `_GLIBCXX_USE_PTRACE`.
  - Bazel status: modeled for Linux; Windows debug API unsupported.

- `GLIBCXX_CHECK_STDIO_LOCKING`
  - Probes:
    - `flockfile`, `putc_unlocked`, `funlockfile`.
    - `fwrite_unlocked` if stdio locking exists -> `HAVE_FWRITE_UNLOCKED`.
    - On GNU/Linux/kfreebsd-gnu/knetbsd-gnu, glibc `FILE` internals plus
      `<stdio_ext.h>` functions `__fwritable`, `__flbf`, `__fbufsize`,
      `__overflow`, `_IO_write_ptr`, `_IO_buf_end`, `fflush_unlocked` ->
      `_GLIBCXX_USE_GLIBC_STDIO_EXT`.
  - Outputs: `_GLIBCXX_USE_STDIO_LOCKING`, `HAVE_FWRITE_UNLOCKED`,
    `_GLIBCXX_USE_GLIBC_STDIO_EXT`.
  - Bazel status: modeled.

## Build-only, docs, install, generated-file checks

- `GLIBCXX_CONFIGURE_TESTSUITE`
  - Condition: after symvers/native decision.
  - Outputs: testsuite flags and conditionals.
  - Bazel status: not relevant to runtime build.

- Documentation tools.
  - Probes: `makeinfo`, `doxygen`, `dot`, `xmlcatalog`, `xsltproc`, `xmllint`,
    `dblatex`, `pdflatex`.
  - Outputs: `BUILD_INFO`, `BUILD_XML`, `BUILD_HTML`, `BUILD_MAN`,
    `BUILD_PDF`.
  - Bazel status: not relevant to runtime build.

- `GLIBCXX_CONFIGURE_DOCBOOK`
  - Checks stylesheet/catalog availability for docs.
  - Bazel status: not relevant.

- Include dir not parallel.
  - Condition: build on Darwin.
  - Output: `INCLUDE_DIR_NOTPARALLEL`.
  - Bazel status: not relevant.

- Source-directory substitutions.
  - Outputs: `ATOMICITY_SRCDIR`, `ATOMIC_WORD_SRCDIR`, `ATOMIC_FLAGS`,
    `CPU_DEFINES_SRCDIR`, `OS_INC_SRCDIR`, `ERROR_CONSTANTS_SRCDIR`,
    `ABI_TWEAKS_SRCDIR`, `CPU_OPT_EXT_RANDOM`, `CPU_OPT_BITS_RANDOM`.
  - Bazel status: mostly modeled in `configure.bzl` and header/source labels.

- `tmake_file` filtering.
  - Condition: files from `configure.host`.
  - Output: existing `config/$f` tmake files only.
  - Bazel status: not modeled; source/flag effects should be audited when
    target-specific make fragments matter.

- Export install/include/flag information.
  - Source: `GLIBCXX_EXPORT_INSTALL_INFO`, `GLIBCXX_EXPORT_INCLUDES`,
    `GLIBCXX_EXPORT_FLAGS`.
  - Output: install paths, include search flags, build flags.
  - Bazel status: partially replaced by header overlays and cc deps; exact
    include order should continue to mirror Makefile behavior.

- `AC_CONFIG_FILES` and `AC_CONFIG_COMMANDS`.
  - Files: `Makefile`, `scripts/testsuite_flags`, `scripts/extract_symvers`,
    `doc/xsl/customization.xsl`, `src/libbacktrace/backtrace-supported.h`, all
    subdirectory Makefiles.
  - Command: `(cd include && ${MAKE-make} pch_build= )`.
  - Bazel status: not modeled; header generation manually ports the relevant
    Makefile include rules.

## Work checklist

- [x] Fetch or otherwise expose `libstdc++-v3/configure.host` in the GCC
  repository so this audit can cover it directly.
- [x] Fetch or otherwise expose `libstdc++-v3/crossconfig.m4` if non-glibc
  cross support is ever considered.
- [x] Fetch or otherwise expose the selected top-level GCC `config/*.m4`
  macros used by libstdc++ configure sources.
- [x] Split the Bazel configure model into source-counterpart files:
  `runtimes/configure/native_autoconf_checks.bzl`,
  `runtimes/libstdcxx/acinclude_checks.bzl`,
  `runtimes/libstdcxx/crossconfig_checks.bzl`, and
  `runtimes/libstdcxx/configure_ac_checks.bzl`.
- [x] Point `config_probe.bzl` directly at `configure_ac_checks.bzl` without a
  compatibility facade.
- [x] Split `config_define_status.txt` statuses into `probe-modeled`,
  `policy-modeled`, `target-derived`, `unsupported`, and `not-needed`.
- [x] Fix `HAVE_GETIPINFO` to model `_Unwind_GetIPInfo`, not `getaddrinfo`.
- [x] Replace the weak `_GLIBCXX_USE_LFS` check with GCC's full
  `GLIBCXX_CHECK_LFS` group.
- [x] Decide whether `AC_SYS_LARGEFILE` needs an explicit Bazel equivalent for
  any supported target.
- [x] Audit every `GLIBCXX_ENABLE_C99` C++98 output and decide probe vs hosted
  glibc policy.
- [x] Audit every `GLIBCXX_ENABLE_C99` C++11 output and decide probe vs hosted
  glibc policy.
- [x] Replace or explicitly justify policy-defined `GLIBCXX_CHECK_C99_TR1`
  outputs.
- [ ] Check that wide-character support is semantically equivalent to
  `GLIBCXX_ENABLE_WCHAR_T`, not only `HAVE_MBSTATE_T`.
- [ ] Compare `GLIBCXX_CHECK_MATH11_PROTO` Solaris-only defines with the current
  unsupported target list.
- [ ] Compare current math function probes against `GLIBCXX_CHECK_MATH_SUPPORT`
  and `GLIBCXX_CHECK_MATH_DECLS`.
- [ ] Compare stdlib function probes against `GLIBCXX_CHECK_STDLIB_SUPPORT`.
- [ ] Decide whether `/dev/random` should remain a Linux policy or become a
  hermetic-compatible configured policy setting.
- [ ] Revisit `GLIBCXX_ENABLE_LIBSTDCXX_TIME` syscall fallback and `timespec`
  compatibility for Linux.
- [ ] Revisit `GLIBCXX_COMPUTE_STDIO_INTEGER_CONSTANTS`; keep glibc constants
  as policy only if all supported targets agree.
- [ ] Audit `GLIBCXX_ENABLE_ATOMIC_BUILTINS` for every supported architecture,
  especially avoiding implicit libatomic dependencies.
- [ ] Audit `GLIBCXX_ENABLE_LOCK_POLICY` for RISC-V and any target where GCC
  chooses mutex for ABI compatibility.
- [ ] Audit `GLIBCXX_CHECK_GTHREADS` in the exact staged `gthr.h` context.
- [ ] Review whether NLS should remain unsupported or become a build setting.
- [ ] Review whether `--enable-cstdio=stdio_pure` should remain unsupported or
  become a build setting.
- [ ] Review whether allocator `malloc` should remain unsupported or become a
  build setting.
- [ ] Review whether `--enable-libstdcxx-verbose` should become a build setting.
- [ ] Review whether decimal floating point should become a probe/build setting
  and whether `_GLIBCXX_USE_DECIMAL_FLOAT` should be target-derived.
- [ ] Review whether float128 should become a probe/build setting instead of a
  fixed target policy, including automatic addition of `float128.ver`.
- [ ] Review whether concept checks, debug library builds, parallel mode,
  extern-template selection, fully dynamic strings, vtable verification,
  custom C++ flags, and Werror remain unsupported/policy-fixed or need exposed
  knobs.
- [ ] Audit symbol versioning decisions against the current `cc_shared_library`
  link path, including shared libgcc assumptions.
- [ ] Audit size_t/ptrdiff_t compatibility defines for non-LP64 targets.
- [ ] Audit long-double compatibility for s390x before claiming s390x parity.
- [ ] Decide whether CET flags should be a target-library build policy.
- [ ] Decide whether Solaris HWCAP checks stay permanently unsupported.
- [ ] Decide whether libbacktrace/`HAVE_STACKTRACE` stays unsupported.
- [ ] Decide whether emergency EH pool knobs should become private build
  settings.
- [ ] Decide whether `_GLIBCXX_STATIC_TZDATA` should be supported.
- [ ] Verify filesystem probes match GCC's exact source snippets and headers.
- [ ] Verify networking header/declaration checks match GCC's exact
  `F_GETFL`/`F_SETFL`/`O_NONBLOCK` conditions.
- [ ] Verify `GLIBCXX_CHECK_TEXT_ENCODING`, `GLIBCXX_CHECK_DEBUGGING`, and
  `GLIBCXX_CHECK_STDIO_LOCKING` use compile probes rather than link probes when
  GCC only compiles.
- [ ] Review build-only/doc/install macros and mark them permanently
  `not-needed` in the status file.
- [ ] Add an automated audit test that extracts `AC_DEFINE`,
  `AC_DEFINE_UNQUOTED`, `AC_CHECK_HEADERS`, and `AC_CHECK_FUNCS` references
  from `configure.ac` and `acinclude.m4`, then compares them to the Bazel status
  file.
- [ ] Extend that audit test to identify called `GLIBCXX_*` and `GCC_*` macros
  so new GCC macro calls are not silently missed during a GCC source update.
