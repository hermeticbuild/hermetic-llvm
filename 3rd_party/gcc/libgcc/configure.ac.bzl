# libgcc/configure.ac's checks, as autoconf checks for the toolchain of the
# platform libgcc builds for. Each is a probe where configure's check fits this
# toolchain, or a fixed policy value where it does not. The checks that come
# from GCC's top-level config/*.m4 files are shared with the libstdc++ port in
# //3rd_party/gcc:gcc_config_checks.bzl.
#
# libgcc_auto_target_checks renders auto-target.h, and
# libgcc_configure_cflags_checks the -D flags configure substitutes into
# INTERNAL_CFLAGS. LIBGCC_SELECTION_CHECKS holds the results that decide what
# the build includes: what gcc/config.gcc and libgcc/config.host select, and
# the configure results that Makefile.in's conditionals read. The build takes
# those selections from target_config.bzl and makefile.bzl at loading time,
# before any probe, which is a Bazel action, can run. Only
# //runtimes/libgcc/tests:configure_* uses LIBGCC_SELECTION_CHECKS: a probe
# result that would change a selection fails it.

load(
    "//3rd_party/gcc:gcc_config_checks.bzl",
    "gcc_check_cc_tls",
    "gcc_check_emutls",
    "gcc_check_unwind_getipinfo",
)
load("//3rd_party/gcc:version.bzl", "gcc_version_at_least_for")
load(
    "//3rd_party/gcc/autoconf:checks.bzl",
    "ac_check_headers",
    "ac_check_sizeof",
    "ac_header_stdc",
    "compile_check",
    "policy_define",
    "policy_string_define",
    "policy_undef",
)

# AC_LANG_PROGRAM, the source of AC_TRY_COMPILE and AC_COMPILE_IFELSE checks
# that give a function body and, optionally, a prologue.
def _program(body, prologue = ""):
    return """{}
int
main (void)
{{
{}
  ;
  return 0;
}}
""".format(prologue, body)

# The checks only some CPUs run, under configure.ac's case on the target.
_CPU_AUTO_TARGET_CHECKS = {
    "aarch64": [
        # LIBGCC_CHECK_AS_LSE
        compile_check(
            name = "HAVE_AS_LSE",
            source = _program('asm(".arch armv8-a+lse\\n\\tcas w0, w1, [x2]");'),
        ),
        # LIBGCC_CHECK_AS_VARIANT_PCS
        compile_check(
            name = "HAVE_AS_VARIANT_PCS",
            source = _program('asm (".variant_pcs foobar");'),
        ),
        # configure.ac sets this for *-linux-gnu without a check, since the
        # C library may not be built yet.
        policy_define("HAVE___GETAUXVAL"),
    ],
    "x86_64": [
        # LIBGCC_CHECK_AS_AVX
        compile_check(
            name = "HAVE_AS_AVX",
            source = _program('asm("vzeroupper");'),
        ),
    ],
}

def libgcc_auto_target_checks(cpu, version):
    """The checks that write auto-target.h, in configure.ac's order."""
    if cpu not in _CPU_AUTO_TARGET_CHECKS:
        fail("libgcc's configure checks are not ported for " + cpu)
    return [
        # AC_INIT
        policy_string_define("PACKAGE_BUGREPORT", ""),
        policy_string_define("PACKAGE_NAME", "GNU C Runtime Library"),
        policy_string_define("PACKAGE_STRING", "GNU C Runtime Library 1.0"),
        policy_string_define("PACKAGE_TARNAME", "libgcc"),
        policy_string_define("PACKAGE_URL", "http://www.gnu.org/software/libgcc/"),
        policy_string_define("PACKAGE_VERSION", "1.0"),
        # AC_SYS_LARGEFILE defines neither where off_t already has 64 bits, as
        # on every ported CPU.
        policy_undef("_FILE_OFFSET_BITS"),
        policy_undef("_LARGE_FILES"),
        ac_check_sizeof("double"),
        ac_check_sizeof("long double"),
    ] + ac_check_headers([
        "inttypes.h",
        "stdint.h",
        "stdlib.h",
        "ftw.h",
        "unistd.h",
        "sys/stat.h",
        "sys/types.h",
        "string.h",
        "strings.h",
        "memory.h",
        "sys/auxv.h",
    ] + (["sys/mman.h"] if gcc_version_at_least_for(version, "11.0.0") else [])) + [
        ac_header_stdc(),
    ] + gcc_check_unwind_getipinfo() + [
        # libgcc_cv_hidden_visibility_attribute, which defines the directive
        # config.host sets as asm_hidden_op.
        compile_check(
            name = "AS_HIDDEN_DIRECTIVE",
            source = 'int __attribute__ ((visibility ("hidden"))) foo (void) { return 1; }',
            flags = ["-Werror"],
            output_regex = "\\.hidden.*foo",
            value = ".hidden",
        ),
        # libgcc_cv_cfi_sections_directive
        compile_check(
            name = "HAVE_AS_CFI_SECTIONS",
            source = """
int foo (int, char *);
int bar (int x) { char *y = __builtin_alloca (x); return foo (x + 1, y) + 1; }
""",
            flags = [
                "-Werror",
                "-g",
                "-fno-asynchronous-unwind-tables",
                "-fno-unwind-tables",
                "-fno-exceptions",
            ],
            output_regex = "\\.cfi_sections.*\\.debug_frame",
        ),
    ] + _CPU_AUTO_TARGET_CHECKS[cpu] + [
        # libgcc_cv_init_priority
        compile_check(
            name = "HAVE_INIT_PRIORITY",
            source = _program("void ip (void) __attribute__ ((constructor (1)));"),
        ),
    ]

def libgcc_configure_cflags_checks():
    """The -D flags configure.ac substitutes into INTERNAL_CFLAGS.

    These are set_have_cc_tls and set_use_emutls. The configure script GCC
    ships puts them on the command line and not in auto-target.h, because its
    HAVE_CC_TLS lacks the AC_DEFINE that config/tls.m4 has.
    """
    return gcc_check_cc_tls() + gcc_check_emutls()

LIBGCC_SELECTION_CHECKS = [
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
    # libgcc/configure.ac: the thread model from GCC_AC_THREAD_MODEL from GCC 16
    # and, before it, the thread model that the compiler's -v reports. Both come
    # from GCC's --enable-threads, which defaults to posix on Linux.
    policy_string_define("LIBGCC_TARGET_THREAD_FILE", "posix"),
    # libgcc/configure.ac: libgcc_cv_dfp, Makefile.in's decimal_float, which
    # adds the decimal floating-point objects.
    compile_check(
        name = "LIBGCC_CV_DFP",
        source = _program(
            """_Decimal32 x;
int fe_except =
  FE_INVALID|FE_DIVBYZERO|FE_OVERFLOW|FE_UNDERFLOW|FE_INEXACT;""",
            prologue = "#include <fenv.h>",
        ),
    ),
    # libgcc/configure.ac: libgcc_cv_fixed_point, Makefile.in's fixed_point,
    # which adds the fixed-point objects.
    compile_check(
        name = "LIBGCC_CV_FIXED_POINT",
        source = "_Sat _Fract x;",
    ),
    # libgcc/configure.ac: libgcc_cv_strub_support, Makefile.in's
    # HAVE_STRUB_SUPPORT from GCC 14, which adds strub.c. GCC's check compiles
    # without -Werror, so a compiler that ignores the attribute with a warning,
    # as Clang does, passes it too.
    compile_check(
        name = "LIBGCC_CV_STRUB_SUPPORT",
        source = "void __attribute__ ((__strub__)) fn (void) {}",
    ),
]
