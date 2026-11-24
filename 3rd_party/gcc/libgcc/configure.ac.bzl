# The configure results that decide what gcc/config.gcc and libgcc/config.host
# select, ported from libgcc/configure.ac and gcc/configure.ac.
# //runtimes/libgcc/tests:configure_* renders them with the local autoconf
# rules, for each platform's toolchain, and runs the two scripts with them.
#
# The build itself takes those selections from target_config.bzl and
# makefile.bzl at loading time, before any probe, which is a Bazel action, can
# run. The test ties the two together: a probe result that would change a
# selection fails it.

load("//3rd_party/gcc/libstdcxx/autoconf:checks.bzl", "compile_check", "policy_define", "policy_string_define")

LIBGCC_CONFIGURE_CHECKS = [
    # libgcc/configure.ac: "Check 32bit or 64bit", which sets host_address.
    compile_check(
        name = "LIBGCC_HOST_ADDRESS_64",
        source = """
#if defined(__x86_64__) || (!defined(__i386__) && defined(__LP64__)) \\
    || defined(__mips64) || defined(__loongarch64)
#else
#error host_address=32
#endif
""",
    ),
    # libgcc/configure.ac: libgcc_cv_cfi, which adds t-stack on x86.
    compile_check(
        name = "LIBGCC_CV_CFI",
        source = """
asm("\\n\\
\t.text\\n\\
\t.cfi_startproc\\n\\
\t.cfi_personality 0, symbol\\n\\
\t.cfi_endproc");
""",
    ),
    # gcc/configure.ac: enable_initfini_array, which appends initfini-array.h
    # to tm_file. GCC's check links .ctors and .init_array sections and
    # expects the linker to merge them by priority, as GNU ld does. lld keeps
    # .ctors separate, so the check would fail with this toolchain. libgcc must
    # use .init_array regardless, because compiler-rt's crtbegin runs only
    # .init_array.
    policy_define("GCC_ENABLE_INITFINI_ARRAY"),
    # libgcc/configure.ac: GCC_AC_THREAD_MODEL, from GCC's --enable-threads,
    # which defaults to posix on Linux.
    policy_string_define("LIBGCC_TARGET_THREAD_FILE", "posix"),
]
