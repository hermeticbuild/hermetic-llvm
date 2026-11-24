# Configuration headers for building libgcc with Clang, for Linux GNU targets.
#
# GCC builds libgcc with the xgcc it has just built, and libgcc reads three
# kinds of configuration from that build:
#
# - Headers generated in GCC's build directory: tconfig.h and tm.h from
#   gcc/mkconfig.sh, with the tm_file list and tm_defines that gcc/config.gcc
#   selects, and the parts of auto-host.h that libgcc reads. tm.h also includes
#   the generated options.h, insn-constants.h and insn-modes.h. libgcc uses
#   none of their contents, so they are stand-ins here, except for the
#   constants the target headers need to declare their tables.
# - Headers libgcc's own configure writes: libgcc_tm.h (libgcc/mkheader.sh
#   with config.host's tm_file) and the LIBGCC_LINKS copies that Makefile.in
#   makes. configure's checks for auto-target.h are ported in configure.ac.bzl,
#   as probes or policy.
# - Macros GCC predefines under -fbuilding-libgcc
#   (gcc/c-family/c-cppbuiltin.cc). Clang does not support that option, so
#   these are written to a header that every libgcc source includes first.
#   The values were taken from each GCC version's xgcc with
#   -fbuilding-libgcc -dM -E. Clang lacks the __FLT128_* and __BFLT16_*
#   macros, so those values are spelled out.
#
# One more header maps the few GCC builtins that libgcc uses and Clang does not
# provide to what GCC expands them to.

load("//3rd_party/gcc:version.bzl", "gcc_version_at_least_for")

_TCONFIG_H = [
    "#ifndef GCC_TCONFIG_H",
    "#define GCC_TCONFIG_H",
    "#ifndef USED_FOR_TARGET",
    "# define USED_FOR_TARGET",
    "#endif",
    "#include \"auto-host.h\"",
    "#ifdef IN_GCC",
    "# include \"ansidecl.h\"",
    "#endif",
    "#endif /* GCC_TCONFIG_H */",
]

# What libgcc reads from GCC's auto-host.h. Most of it is the defines that
# gcc/config.in leaves outside #ifndef USED_FOR_TARGET, as GCC's configure sets
# them for a GNU assembler and linker on Linux. The toolchain's integrated
# assembler and lld support the same features. The rest is host-only: sources
# that include auto-host.h directly, without tconfig.h, also see the defines
# under #ifndef USED_FOR_TARGET. Of the ported sources only
# config/i386/morestack.S does, and it reads HAVE_INITFINI_ARRAY_SUPPORT to
# register __stack_split_initialize in .init_array. Without it the constructor
# goes to .ctors, which compiler-rt's crtbegin does not run.
#
# ENABLE_RUNTIME_CHECKING comes from the runtime checks that GCC's
# --enable-checking includes by default. It makes gcc/tsystem.h's gcc_assert
# call abort () when its condition fails, as the unwinder's assertions do in
# GCC's libgcc. GCC's configure defines TARGET_DL_ITERATE_PHDR only for Solaris,
# FreeBSD, DragonFly and musl, so a glibc target leaves it out.
_AUTO_HOST_H = [
    "/* The parts of GCC's auto-host.h that libgcc reads.  */",
    "#define ENABLE_RUNTIME_CHECKING 1",
    "#define HAVE_GAS_CFI_DIRECTIVE 1",
    "#define HAVE_GAS_CFI_PERSONALITY_DIRECTIVE 1",
    "#define HAVE_GAS_CFI_SECTIONS_DIRECTIVE 1",
    "#define HAVE_GAS_HIDDEN 1",
    "#define HAVE_LD_EH_FRAME_HDR 1",
    "#ifndef USED_FOR_TARGET",
    "#define HAVE_INITFINI_ARRAY_SUPPORT 1",
    "#endif",
]

def _mkconfig_tm_h(defines, headers):
    """gcc/mkconfig.sh output for tm.h."""
    lines = ["#ifndef GCC_TM_H", "#define GCC_TM_H"]
    for define in defines:
        name, _, value = define.partition("=")
        lines += [
            "#ifndef " + name,
            "# define {} {}".format(name, value) if value else "# define " + name,
            "#endif",
        ]
    lines.append("#ifdef IN_GCC")
    lines += ["# include \"{}\"".format(h) for h in ["options.h", "insn-constants.h"] + headers]
    lines += [
        "#endif",
        "#if defined IN_GCC && !defined GENERATOR_FILE && !defined USED_FOR_TARGET",
        "# include \"insn-flags.h\"",
        "#endif",
        "#if defined IN_GCC && !defined GENERATOR_FILE",
        "# include \"insn-modes.h\"",
        "#endif",
        "# include \"defaults.h\"",
        "#endif /* GCC_TM_H */",
    ]
    return lines

# What GCC 14.2.0 through 17 predefine under -fbuilding-libgcc for x86-64
# Linux.
_X86_64_PREDEFINES_GCC14 = [
    "#define __LIBGCC_BF_EPSILON__ ((__bf16) 7.81250000000000000000000000000000000e-3F)",
    "#define __LIBGCC_BF_EXCESS_PRECISION__ 1",
    "#define __LIBGCC_BF_FUNC_EXT__ bf16",
    "#define __LIBGCC_BF_MANT_DIG__ 8",
    "#define __LIBGCC_BF_MAX__ ((__bf16) 3.38953138925153547590470800371487867e+38F)",
    "#define __LIBGCC_BF_MIN__ ((__bf16) 1.17549435082228750796873653722224568e-38F)",
    "#define __LIBGCC_BITINT_LIMB_WIDTH__ 64",
    "#define __LIBGCC_BITINT_ORDER__ __ORDER_LITTLE_ENDIAN__",
    "#define __LIBGCC_DF_EPSILON__ __DBL_EPSILON__",
    "#define __LIBGCC_DF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_DF_FUNC_EXT__",
    "#define __LIBGCC_DF_MANT_DIG__ 53",
    "#define __LIBGCC_DF_MAX__ __DBL_MAX__",
    "#define __LIBGCC_DF_MIN__ __DBL_MIN__",
    "#define __LIBGCC_DWARF_CIE_DATA_ALIGNMENT__ -8",
    "#define __LIBGCC_DWARF_FRAME_REGISTERS__ 17",
    "#define __LIBGCC_EH_FRAME_SECTION_NAME__ \".eh_frame\"",
    "#define __LIBGCC_EH_RETURN_STACKADJ_RTX__ 1",
    "#define __LIBGCC_EH_TABLES_CAN_BE_READ_ONLY__ 1",
    "#define __LIBGCC_HAS_BF_MODE__ 1",
    "#define __LIBGCC_HAS_DF_MODE__ 1",
    "#define __LIBGCC_HAS_HF_MODE__ 1",
    "#define __LIBGCC_HAS_SF_MODE__ 1",
    "#define __LIBGCC_HAS_TF_MODE__ 1",
    "#define __LIBGCC_HAS_XF_MODE__ 1",
    "#define __LIBGCC_HAVE_HWDBL__ 1",
    "#define __LIBGCC_HAVE_LIBATOMIC 0",
    "#define __LIBGCC_HF_EPSILON__ __FLT16_EPSILON__",
    "#define __LIBGCC_HF_EXCESS_PRECISION__ 1",
    "#define __LIBGCC_HF_FUNC_EXT__ f16",
    "#define __LIBGCC_HF_MANT_DIG__ 11",
    "#define __LIBGCC_HF_MAX__ __FLT16_MAX__",
    "#define __LIBGCC_HF_MIN__ __FLT16_MIN__",
    "#define __LIBGCC_INIT_ARRAY_SECTION_ASM_OP__ 1",
    "#define __LIBGCC_SF_EPSILON__ __FLT_EPSILON__",
    "#define __LIBGCC_SF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_SF_FUNC_EXT__ f",
    "#define __LIBGCC_SF_MANT_DIG__ 24",
    "#define __LIBGCC_SF_MAX__ __FLT_MAX__",
    "#define __LIBGCC_SF_MIN__ __FLT_MIN__",
    "#define __LIBGCC_STACK_GROWS_DOWNWARD__ 1",
    "#define __LIBGCC_STACK_POINTER_REGNUM__ 7",
    "#define __LIBGCC_TEXT_SECTION_ASM_OP__ \"\\t.text\"",
    "#define __LIBGCC_TF_EPSILON__ 1.92592994438723585305597794258492732e-34Q",
    "#define __LIBGCC_TF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_TF_FUNC_EXT__ f128",
    "#define __LIBGCC_TF_MANT_DIG__ 113",
    "#define __LIBGCC_TF_MAX__ 1.18973149535723176508575932662800702e+4932Q",
    "#define __LIBGCC_TF_MIN__ 3.36210314311209350626267781732175260e-4932Q",
    "#define __LIBGCC_TRAMPOLINE_SIZE__ 28",
    "#define __LIBGCC_VTABLE_USES_DESCRIPTORS__ 0",
    "#define __LIBGCC_XF_EPSILON__ __LDBL_EPSILON__",
    "#define __LIBGCC_XF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_XF_FUNC_EXT__ l",
    "#define __LIBGCC_XF_MANT_DIG__ 64",
    "#define __LIBGCC_XF_MAX__ __LDBL_MAX__",
    "#define __LIBGCC_XF_MIN__ __LDBL_MIN__",
    # The libgcc_cmp_return_mode and libgcc_shift_count_mode target hooks
    # name these modes; both are word_mode on x86-64.
    "#define __libgcc_cmp_return__ __word__",
    "#define __libgcc_shift_count__ __word__",
]

# What GCC 9.1.0 through 11.5.0 predefine under -fbuilding-libgcc for x86-64
# Linux.
_X86_64_PREDEFINES_GCC10 = [
    "#define __LIBGCC_DF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_DF_FUNC_EXT__",
    "#define __LIBGCC_DF_MANT_DIG__ 53",
    "#define __LIBGCC_DWARF_FRAME_REGISTERS__ 17",
    "#define __LIBGCC_EH_FRAME_SECTION_NAME__ \".eh_frame\"",
    "#define __LIBGCC_EH_RETURN_STACKADJ_RTX__ 1",
    "#define __LIBGCC_EH_TABLES_CAN_BE_READ_ONLY__ 1",
    "#define __LIBGCC_HAS_DF_MODE__ 1",
    "#define __LIBGCC_HAS_SF_MODE__ 1",
    "#define __LIBGCC_HAS_TF_MODE__ 1",
    "#define __LIBGCC_HAS_XF_MODE__ 1",
    "#define __LIBGCC_INIT_ARRAY_SECTION_ASM_OP__ 1",
    "#define __LIBGCC_SF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_SF_FUNC_EXT__ f",
    "#define __LIBGCC_SF_MANT_DIG__ 24",
    "#define __LIBGCC_STACK_GROWS_DOWNWARD__ 1",
    "#define __LIBGCC_STACK_POINTER_REGNUM__ 7",
    "#define __LIBGCC_TEXT_SECTION_ASM_OP__ \"\\t.text\"",
    "#define __LIBGCC_TF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_TF_FUNC_EXT__ f128",
    "#define __LIBGCC_TF_MANT_DIG__ 113",
    "#define __LIBGCC_TRAMPOLINE_SIZE__ 28",
    "#define __LIBGCC_VTABLE_USES_DESCRIPTORS__ 0",
    "#define __LIBGCC_XF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_XF_FUNC_EXT__ l",
    "#define __LIBGCC_XF_MANT_DIG__ 64",
    "#define __libgcc_cmp_return__ __word__",
    "#define __libgcc_shift_count__ __word__",
]

# What GCC 12 predefines under -fbuilding-libgcc for x86-64 Linux, the same in
# 12.1.0 through 12.5.0.
_X86_64_PREDEFINES_GCC12 = [
    "#define __LIBGCC_DF_EPSILON__ __DBL_EPSILON__",
    "#define __LIBGCC_DF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_DF_FUNC_EXT__",
    "#define __LIBGCC_DF_MANT_DIG__ 53",
    "#define __LIBGCC_DF_MAX__ __DBL_MAX__",
    "#define __LIBGCC_DF_MIN__ __DBL_MIN__",
    "#define __LIBGCC_DWARF_FRAME_REGISTERS__ 17",
    "#define __LIBGCC_EH_FRAME_SECTION_NAME__ \".eh_frame\"",
    "#define __LIBGCC_EH_RETURN_STACKADJ_RTX__ 1",
    "#define __LIBGCC_EH_TABLES_CAN_BE_READ_ONLY__ 1",
    "#define __LIBGCC_GCOV_TYPE_SIZE 64",
    "#define __LIBGCC_HAS_DF_MODE__ 1",
    "#define __LIBGCC_HAS_HF_MODE__ 1",
    "#define __LIBGCC_HAS_SF_MODE__ 1",
    "#define __LIBGCC_HAS_TF_MODE__ 1",
    "#define __LIBGCC_HAS_XF_MODE__ 1",
    "#define __LIBGCC_HAVE_HWDBL__ 1",
    "#define __LIBGCC_HF_EPSILON__ __FLT16_EPSILON__",
    "#define __LIBGCC_HF_EXCESS_PRECISION__ 1",
    "#define __LIBGCC_HF_FUNC_EXT__ f16",
    "#define __LIBGCC_HF_MANT_DIG__ 11",
    "#define __LIBGCC_HF_MAX__ __FLT16_MAX__",
    "#define __LIBGCC_HF_MIN__ __FLT16_MIN__",
    "#define __LIBGCC_INIT_ARRAY_SECTION_ASM_OP__ 1",
    "#define __LIBGCC_SF_EPSILON__ __FLT_EPSILON__",
    "#define __LIBGCC_SF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_SF_FUNC_EXT__ f",
    "#define __LIBGCC_SF_MANT_DIG__ 24",
    "#define __LIBGCC_SF_MAX__ __FLT_MAX__",
    "#define __LIBGCC_SF_MIN__ __FLT_MIN__",
    "#define __LIBGCC_STACK_GROWS_DOWNWARD__ 1",
    "#define __LIBGCC_STACK_POINTER_REGNUM__ 7",
    "#define __LIBGCC_TEXT_SECTION_ASM_OP__ \"\\t.text\"",
    "#define __LIBGCC_TF_EPSILON__ 1.92592994438723585305597794258492732e-34Q",
    "#define __LIBGCC_TF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_TF_FUNC_EXT__ f128",
    "#define __LIBGCC_TF_MANT_DIG__ 113",
    "#define __LIBGCC_TF_MAX__ 1.18973149535723176508575932662800702e+4932Q",
    "#define __LIBGCC_TF_MIN__ 3.36210314311209350626267781732175260e-4932Q",
    "#define __LIBGCC_TRAMPOLINE_SIZE__ 28",
    "#define __LIBGCC_VTABLE_USES_DESCRIPTORS__ 0",
    "#define __LIBGCC_XF_EPSILON__ __LDBL_EPSILON__",
    "#define __LIBGCC_XF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_XF_FUNC_EXT__ l",
    "#define __LIBGCC_XF_MANT_DIG__ 64",
    "#define __LIBGCC_XF_MAX__ __LDBL_MAX__",
    "#define __LIBGCC_XF_MIN__ __LDBL_MIN__",
    # The libgcc_cmp_return_mode and libgcc_shift_count_mode target hooks
    # name these modes; both are word_mode on x86-64.
    "#define __libgcc_cmp_return__ __word__",
    "#define __libgcc_shift_count__ __word__",
]

# What GCC 13 predefines under -fbuilding-libgcc for x86-64 Linux, the same in
# 13.1.0 through 13.4.0.
_X86_64_PREDEFINES_GCC13 = [
    "#define __LIBGCC_BF_EPSILON__ ((__bf16) 7.81250000000000000000000000000000000e-3F)",
    "#define __LIBGCC_BF_EXCESS_PRECISION__ 1",
    "#define __LIBGCC_BF_FUNC_EXT__ bf16",
    "#define __LIBGCC_BF_MANT_DIG__ 8",
    "#define __LIBGCC_BF_MAX__ ((__bf16) 3.38953138925153547590470800371487867e+38F)",
    "#define __LIBGCC_BF_MIN__ ((__bf16) 1.17549435082228750796873653722224568e-38F)",
    "#define __LIBGCC_DF_EPSILON__ __DBL_EPSILON__",
    "#define __LIBGCC_DF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_DF_FUNC_EXT__",
    "#define __LIBGCC_DF_MANT_DIG__ 53",
    "#define __LIBGCC_DF_MAX__ __DBL_MAX__",
    "#define __LIBGCC_DF_MIN__ __DBL_MIN__",
    "#define __LIBGCC_DWARF_CIE_DATA_ALIGNMENT__ -8",
    "#define __LIBGCC_DWARF_FRAME_REGISTERS__ 17",
    "#define __LIBGCC_EH_FRAME_SECTION_NAME__ \".eh_frame\"",
    "#define __LIBGCC_EH_RETURN_STACKADJ_RTX__ 1",
    "#define __LIBGCC_EH_TABLES_CAN_BE_READ_ONLY__ 1",
    "#define __LIBGCC_GCOV_TYPE_SIZE 64",
    "#define __LIBGCC_HAS_BF_MODE__ 1",
    "#define __LIBGCC_HAS_DF_MODE__ 1",
    "#define __LIBGCC_HAS_HF_MODE__ 1",
    "#define __LIBGCC_HAS_SF_MODE__ 1",
    "#define __LIBGCC_HAS_TF_MODE__ 1",
    "#define __LIBGCC_HAS_XF_MODE__ 1",
    "#define __LIBGCC_HAVE_HWDBL__ 1",
    "#define __LIBGCC_HF_EPSILON__ __FLT16_EPSILON__",
    "#define __LIBGCC_HF_EXCESS_PRECISION__ 1",
    "#define __LIBGCC_HF_FUNC_EXT__ f16",
    "#define __LIBGCC_HF_MANT_DIG__ 11",
    "#define __LIBGCC_HF_MAX__ __FLT16_MAX__",
    "#define __LIBGCC_HF_MIN__ __FLT16_MIN__",
    "#define __LIBGCC_INIT_ARRAY_SECTION_ASM_OP__ 1",
    "#define __LIBGCC_SF_EPSILON__ __FLT_EPSILON__",
    "#define __LIBGCC_SF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_SF_FUNC_EXT__ f",
    "#define __LIBGCC_SF_MANT_DIG__ 24",
    "#define __LIBGCC_SF_MAX__ __FLT_MAX__",
    "#define __LIBGCC_SF_MIN__ __FLT_MIN__",
    "#define __LIBGCC_STACK_GROWS_DOWNWARD__ 1",
    "#define __LIBGCC_STACK_POINTER_REGNUM__ 7",
    "#define __LIBGCC_TEXT_SECTION_ASM_OP__ \"\\t.text\"",
    "#define __LIBGCC_TF_EPSILON__ 1.92592994438723585305597794258492732e-34Q",
    "#define __LIBGCC_TF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_TF_FUNC_EXT__ f128",
    "#define __LIBGCC_TF_MANT_DIG__ 113",
    "#define __LIBGCC_TF_MAX__ 1.18973149535723176508575932662800702e+4932Q",
    "#define __LIBGCC_TF_MIN__ 3.36210314311209350626267781732175260e-4932Q",
    "#define __LIBGCC_TRAMPOLINE_SIZE__ 28",
    "#define __LIBGCC_VTABLE_USES_DESCRIPTORS__ 0",
    "#define __LIBGCC_XF_EPSILON__ __LDBL_EPSILON__",
    "#define __LIBGCC_XF_EXCESS_PRECISION__ 0",
    "#define __LIBGCC_XF_FUNC_EXT__ l",
    "#define __LIBGCC_XF_MANT_DIG__ 64",
    "#define __LIBGCC_XF_MAX__ __LDBL_MAX__",
    "#define __LIBGCC_XF_MIN__ __LDBL_MIN__",
    # The libgcc_cmp_return_mode and libgcc_shift_count_mode target hooks
    # name these modes; both are word_mode on x86-64.
    "#define __libgcc_cmp_return__ __word__",
    "#define __libgcc_shift_count__ __word__",
]

_X86_64_PREDEFINES = {
    "9.1.0": _X86_64_PREDEFINES_GCC10,
    "9.2.0": _X86_64_PREDEFINES_GCC10,
    "9.3.0": _X86_64_PREDEFINES_GCC10,
    "9.4.0": _X86_64_PREDEFINES_GCC10,
    "9.5.0": _X86_64_PREDEFINES_GCC10,
    "10.1.0": _X86_64_PREDEFINES_GCC10,
    "10.2.0": _X86_64_PREDEFINES_GCC10,
    "10.3.0": _X86_64_PREDEFINES_GCC10,
    "10.4.0": _X86_64_PREDEFINES_GCC10,
    "10.5.0": _X86_64_PREDEFINES_GCC10,
    "11.1.0": _X86_64_PREDEFINES_GCC10,
    "11.2.0": _X86_64_PREDEFINES_GCC10,
    "11.3.0": _X86_64_PREDEFINES_GCC10,
    "11.4.0": _X86_64_PREDEFINES_GCC10,
    "11.5.0": _X86_64_PREDEFINES_GCC10,
    "12.1.0": _X86_64_PREDEFINES_GCC12,
    "12.2.0": _X86_64_PREDEFINES_GCC12,
    "12.3.0": _X86_64_PREDEFINES_GCC12,
    "12.4.0": _X86_64_PREDEFINES_GCC12,
    "12.5.0": _X86_64_PREDEFINES_GCC12,
    "13.1.0": _X86_64_PREDEFINES_GCC13,
    "13.2.0": _X86_64_PREDEFINES_GCC13,
    "13.3.0": _X86_64_PREDEFINES_GCC13,
    "13.4.0": _X86_64_PREDEFINES_GCC13,
    "14.2.0": _X86_64_PREDEFINES_GCC14,
    "14.3.0": _X86_64_PREDEFINES_GCC14,
    "15.1.0": _X86_64_PREDEFINES_GCC14,
    "15.2.0": _X86_64_PREDEFINES_GCC14,
    "16.1.0": _X86_64_PREDEFINES_GCC14,
    "17.0.0": _X86_64_PREDEFINES_GCC14,
}

def _x86_64(version):
    return struct(
        # The canonical triple configure runs config.gcc and config.host for.
        triple = "x86_64-pc-linux-gnu",
        # gcc/config.gcc for x86_64-*-linux*.
        tm_defines = [
            "LIBC_GLIBC=1",
            "LIBC_UCLIBC=2",
            "LIBC_BIONIC=3",
            "LIBC_MUSL=4",
            "DEFAULT_LIBC=LIBC_GLIBC",
            "ANDROID_DEFAULT=0",
        ] + (["HEAP_TRAMPOLINES_INIT=0"] if gcc_version_at_least_for(version, "14.0.0") else []),
        tm_file = [
            "config/vxworks-dummy.h",
            "config/i386/biarch64.h",
            "config/i386/i386.h",
            "config/i386/unix.h",
            "config/i386/att.h",
        ] + ([] if gcc_version_at_least_for(version, "13.0.0") else ["config/dbxelf.h"]) + [
            "config/elfos.h",
            "config/gnu-user.h",
            "config/glibc-stdint.h",
            "config/i386/x86-64.h",
            "config/i386/gnu-user-common.h",
            "config/i386/gnu-user64.h",
            "config/linux.h",
            "config/linux-android.h",
            "config/i386/linux-common.h",
            "config/i386/linux64.h",
            "config/initfini-array.h",
        ],
        # i386.h sizes its register tables with this i386.md constant.
        insn_constants = [
            "#define FIRST_PSEUDO_REG {}".format(92 if gcc_version_at_least_for(version, "14.0.0") else 76),
        ],
        # libgcc/config.host for x86_64-*-linux*.
        libgcc_tm_file = [
            "config/i386/elf-lib.h",
            "config/i386/value-unwind.h",
        ],
        # cpuinfo.c includes cpuid.h, which GCC installs from its config/i386
        # directory. Clang's cpuid.h lacks some of the bits it tests.
        extra_links = {
            "cpuid.h": "gcc/config/i386/cpuid.h",
        },
        # config.host sets md_unwind_def_header from GCC 15.
        md_unwind_def_header = "libgcc/config/no-unwind.h" if gcc_version_at_least_for(version, "15.0.0") else None,
        md_unwind_header = "libgcc/config/i386/linux-unwind.h",
        sfp_machine_header = "libgcc/config/i386/sfp-machine.h",
        shlib_mapfiles = [
            "libgcc/config/i386/libgcc-glibc.ver",
        ],
        predefines = _X86_64_PREDEFINES[version],
        clang_compat = [
            "/* libgcc/config/i386/shadow-stack-unwind.h uses GCC's cetintrin.h",
            "   names.  These expand to the builtins GCC's definitions use.  */",
            "#ifndef __ASSEMBLER__",
            "# define _get_ssp() __builtin_ia32_rdsspq (0)",
            "# define _inc_ssp(n) __builtin_ia32_incsspq ((unsigned long long) (n))",
            "#endif",
        ],
        # HOST_LIBGCC2_CFLAGS from i386/t-linux, with CET_FLAGS as libgcc's
        # configure sets them for --enable-cet=auto on x86-64 Linux, and t-tls's
        # INTERNAL_CFLAGS.
        copts = [
            "-mlong-double-80",
            "-DUSE_ELF_SYMVER",
            "-fcf-protection",
            "-mshstk",
            "-DUSE_TLS",
        ],
    )

_AARCH64 = struct(
    # The canonical triple configure runs config.gcc and config.host for.
    triple = "aarch64-unknown-linux-gnu",
    # gcc/config.gcc for aarch64*-*-linux*.
    tm_defines = [
        "LIBC_GLIBC=1",
        "LIBC_UCLIBC=2",
        "LIBC_BIONIC=3",
        "LIBC_MUSL=4",
        "DEFAULT_LIBC=LIBC_GLIBC",
        "ANDROID_DEFAULT=0",
        "HEAP_TRAMPOLINES_INIT=0",
        "TARGET_DEFAULT_ASYNC_UNWIND_TABLES=1",
    ],
    tm_file = [
        "config/vxworks-dummy.h",
        "config/aarch64/biarchlp64.h",
        "config/aarch64/aarch64.h",
        "config/elfos.h",
        "config/gnu-user.h",
        "config/linux.h",
        "config/glibc-stdint.h",
        "config/aarch64/aarch64-elf.h",
        "config/aarch64/aarch64-errata.h",
        "config/aarch64/aarch64-linux.h",
        "config/initfini-array.h",
    ],
    insn_constants = [],
    # libgcc/config.host for aarch64*-*-linux*.
    libgcc_tm_file = [
        "config/aarch64/value-unwind.h",
    ],
    extra_links = {},
    md_unwind_def_header = "libgcc/config/aarch64/aarch64-unwind-def.h",
    md_unwind_header = "libgcc/config/aarch64/linux-unwind.h",
    sfp_machine_header = "libgcc/config/aarch64/sfp-machine.h",
    shlib_mapfiles = [
        "libgcc/config/libgcc-glibc.ver",
        "libgcc/config/aarch64/libgcc-sme.ver",
        "libgcc/config/aarch64/libgcc-softfp.ver",
    ],
    predefines = [
        "#define __LIBGCC_BF_EPSILON__ ((__bf16) 7.81250000000000000000000000000000000e-3F)",
        "#define __LIBGCC_BF_EXCESS_PRECISION__ 0",
        "#define __LIBGCC_BF_FUNC_EXT__ bf16",
        "#define __LIBGCC_BF_MANT_DIG__ 8",
        "#define __LIBGCC_BF_MAX__ ((__bf16) 3.38953138925153547590470800371487867e+38F)",
        "#define __LIBGCC_BF_MIN__ ((__bf16) 1.17549435082228750796873653722224568e-38F)",
        "#define __LIBGCC_BITINT_LIMB_WIDTH__ 64",
        "#define __LIBGCC_BITINT_ORDER__ __ORDER_LITTLE_ENDIAN__",
        "#define __LIBGCC_CTORS_SECTION_ASM_OP__ \"\\t.section\\t.init_array,\\\"aw\\\",%init_array\"",
        "#define __LIBGCC_DF_EPSILON__ __DBL_EPSILON__",
        "#define __LIBGCC_DF_EXCESS_PRECISION__ 0",
        "#define __LIBGCC_DF_FUNC_EXT__",
        "#define __LIBGCC_DF_MANT_DIG__ 53",
        "#define __LIBGCC_DF_MAX__ __DBL_MAX__",
        "#define __LIBGCC_DF_MIN__ __DBL_MIN__",
        "#define __LIBGCC_DTORS_SECTION_ASM_OP__ \"\\t.section\\t.fini_array,\\\"aw\\\",%fini_array\"",
        "#define __LIBGCC_DWARF_ALT_FRAME_RETURN_COLUMN__ 96",
        "#define __LIBGCC_DWARF_CIE_DATA_ALIGNMENT__ -8",
        "#define __LIBGCC_DWARF_FRAME_REGISTERS__ 97",
        "#define __LIBGCC_EH_FRAME_SECTION_NAME__ \".eh_frame\"",
        "#define __LIBGCC_EH_RETURN_STACKADJ_RTX__ 1",
        "#define __LIBGCC_EH_TABLES_CAN_BE_READ_ONLY__ 1",
        "#define __LIBGCC_HAS_BF_MODE__ 1",
        "#define __LIBGCC_HAS_DF_MODE__ 1",
        "#define __LIBGCC_HAS_HF_MODE__ 1",
        "#define __LIBGCC_HAS_SF_MODE__ 1",
        "#define __LIBGCC_HAS_TF_MODE__ 1",
        "#define __LIBGCC_HAVE_HWDBL__ 1",
        "#define __LIBGCC_HAVE_LIBATOMIC 0",
        "#define __LIBGCC_HF_EPSILON__ __FLT16_EPSILON__",
        "#define __LIBGCC_HF_EXCESS_PRECISION__ 0",
        "#define __LIBGCC_HF_FUNC_EXT__ f16",
        "#define __LIBGCC_HF_MANT_DIG__ 11",
        "#define __LIBGCC_HF_MAX__ __FLT16_MAX__",
        "#define __LIBGCC_HF_MIN__ __FLT16_MIN__",
        "#define __LIBGCC_INIT_ARRAY_SECTION_ASM_OP__ 1",
        "#define __LIBGCC_SF_EPSILON__ __FLT_EPSILON__",
        "#define __LIBGCC_SF_EXCESS_PRECISION__ 0",
        "#define __LIBGCC_SF_FUNC_EXT__ f",
        "#define __LIBGCC_SF_MANT_DIG__ 24",
        "#define __LIBGCC_SF_MAX__ __FLT_MAX__",
        "#define __LIBGCC_SF_MIN__ __FLT_MIN__",
        "#define __LIBGCC_STACK_GROWS_DOWNWARD__ 1",
        "#define __LIBGCC_STACK_POINTER_REGNUM__ 31",
        "#define __LIBGCC_TEXT_SECTION_ASM_OP__ \"\\t.text\"",
        "#define __LIBGCC_TF_EPSILON__ __LDBL_EPSILON__",
        "#define __LIBGCC_TF_EXCESS_PRECISION__ 0",
        "#define __LIBGCC_TF_FUNC_EXT__ l",
        "#define __LIBGCC_TF_MANT_DIG__ 113",
        "#define __LIBGCC_TF_MAX__ __LDBL_MAX__",
        "#define __LIBGCC_TF_MIN__ __LDBL_MIN__",
        "#define __LIBGCC_TRAMPOLINE_SIZE__ 40",
        "#define __LIBGCC_VTABLE_USES_DESCRIPTORS__ 0",
        # The libgcc_cmp_return_mode and libgcc_shift_count_mode target hooks
        # name these modes: SImode and word_mode on AArch64.
        "#define __libgcc_cmp_return__ __SI__",
        "#define __libgcc_shift_count__ __word__",
    ],
    clang_compat = [
        "/* GCC builtins that libgcc's AArch64 unwinder uses.  Clang lacks them,",
        "   or provides them only with +pauth or +gcs.  Each has GCC's type and",
        "   emits what GCC's aarch64.md pattern does, in encodings that assemble",
        "   without those extensions.  */",
        "#if !defined __ASSEMBLER__",
        "static __inline__ __attribute__ ((__always_inline__)) void *",
        "__libgcc_aarch64_autia1716 (void *__ptr, __UINT64_TYPE__ __salt)",
        "{",
        "  register void *__x17 __asm__ (\"x17\") = __ptr;",
        "  register __UINT64_TYPE__ __x16 __asm__ (\"x16\") = __salt;",
        "  __asm__ (\"hint\\t12 // autia1716\" : \"+r\" (__x17) : \"r\" (__x16));",
        "  return __x17;",
        "}",
        "static __inline__ __attribute__ ((__always_inline__)) void *",
        "__libgcc_aarch64_autib1716 (void *__ptr, __UINT64_TYPE__ __salt)",
        "{",
        "  register void *__x17 __asm__ (\"x17\") = __ptr;",
        "  register __UINT64_TYPE__ __x16 __asm__ (\"x16\") = __salt;",
        "  __asm__ (\"hint\\t14 // autib1716\" : \"+r\" (__x17) : \"r\" (__x16));",
        "  return __x17;",
        "}",
        "static __inline__ __attribute__ ((__always_inline__)) __UINT64_TYPE__",
        "__libgcc_aarch64_chkfeat (__UINT64_TYPE__ __feat)",
        "{",
        "  register __UINT64_TYPE__ __x16 __asm__ (\"x16\") = __feat;",
        "  __asm__ __volatile__ (\"hint\\t40 // chkfeat x16\" : \"+r\" (__x16));",
        "  return __x16;",
        "}",
        "static __inline__ __attribute__ ((__always_inline__)) void *",
        "__libgcc_aarch64_gcspr (void)",
        "{",
        "  void *__gcs;",
        "  __asm__ __volatile__ (\"mrs\\t%0, s3_3_c2_c5_1 // gcspr_el0\" : \"=r\" (__gcs));",
        "  return __gcs;",
        "}",
        "static __inline__ __attribute__ ((__always_inline__)) __UINT64_TYPE__",
        "__libgcc_aarch64_gcspopm (void)",
        "{",
        "  __UINT64_TYPE__ __r = 0;",
        "  __asm__ __volatile__ (\"sysl\\t%0, #3, c7, c7, #1 // gcspopm\"",
        "\t\t\t: \"+r\" (__r) : : \"memory\");",
        "  return __r;",
        "}",
        "/* Clang does not implement __builtin_init_dwarf_reg_size_table for",
        "   AArch64.  These are the entries GCC 17 sets: x0-x30 and sp, VG, the",
        "   callee-saved low halves of v8-v15, and the alternate return column.",
        "   The other entries stay zero.  */",
        "static __inline__ __attribute__ ((__always_inline__)) void",
        "__libgcc_aarch64_init_dwarf_reg_size_table (unsigned char *__t)",
        "{",
        "  for (int __i = 0; __i <= 31; __i++)",
        "    __t[__i] = 8;",
        "  __t[46] = 8;",
        "  for (int __i = 72; __i <= 79; __i++)",
        "    __t[__i] = 8;",
        "  __t[96] = 8;",
        "}",
        "# define __builtin_aarch64_autia1716 __libgcc_aarch64_autia1716",
        "# define __builtin_aarch64_autib1716 __libgcc_aarch64_autib1716",
        "# define __builtin_aarch64_chkfeat __libgcc_aarch64_chkfeat",
        "# define __builtin_aarch64_gcspr __libgcc_aarch64_gcspr",
        "# define __builtin_aarch64_gcspopm __libgcc_aarch64_gcspopm",
        "# define __builtin_init_dwarf_reg_size_table __libgcc_aarch64_init_dwarf_reg_size_table",
        "/* Clang returns the frame pointer for __builtin_dwarf_cfa on AArch64.",
        "   The CFA is the stack pointer at function entry, which",
        "   __builtin_sponentry returns.  */",
        "# define __builtin_dwarf_cfa() __builtin_sponentry ()",
        "#endif",
    ],
    # aarch64/t-aarch64 and aarch64/t-softfp add only warning flags.
    copts = [],
)

# The GCC versions these headers and predefines were taken from, with the CPUs
# of each.
_PORTED_TARGETS = {
    "9.1.0": ["x86_64"],
    "9.2.0": ["x86_64"],
    "9.3.0": ["x86_64"],
    "9.4.0": ["x86_64"],
    "9.5.0": ["x86_64"],
    "10.1.0": ["x86_64"],
    "10.2.0": ["x86_64"],
    "10.3.0": ["x86_64"],
    "10.4.0": ["x86_64"],
    "10.5.0": ["x86_64"],
    "11.1.0": ["x86_64"],
    "11.2.0": ["x86_64"],
    "11.3.0": ["x86_64"],
    "11.4.0": ["x86_64"],
    "11.5.0": ["x86_64"],
    "12.1.0": ["x86_64"],
    "12.2.0": ["x86_64"],
    "12.3.0": ["x86_64"],
    "12.4.0": ["x86_64"],
    "12.5.0": ["x86_64"],
    "13.1.0": ["x86_64"],
    "13.2.0": ["x86_64"],
    "13.3.0": ["x86_64"],
    "13.4.0": ["x86_64"],
    "14.2.0": ["x86_64"],
    "14.3.0": ["x86_64"],
    "15.1.0": ["x86_64"],
    "15.2.0": ["x86_64"],
    "16.1.0": ["x86_64"],
    "17.0.0": [
        "aarch64",
        "x86_64",
    ],
}

def _target(cpu, version):
    if cpu not in _PORTED_TARGETS.get(version, []):
        fail("libgcc's configuration is not ported for {} in GCC {}".format(cpu, version))
    if cpu == "x86_64":
        return _x86_64(version)
    return _AARCH64

def libgcc_header_contents(cpu, version):
    """Lists the configuration headers libgcc's build reads.

    Returns:
      A dict from each generated header's name to its lines. Fails for a
      version or CPU that is not ported.
    """
    t = _target(cpu, version)
    return {
        "auto-host.h": _AUTO_HOST_H,
        "insn-constants.h": ["/* Stand-in for GCC's generated insn-constants.h.  */"] + t.insn_constants,
        "insn-modes.h": ["/* Stand-in for GCC's generated insn-modes.h.  */"],
        "libgcc_clang_compat.h": t.clang_compat,
        "libgcc_predefines.h": ["/* What GCC predefines under -fbuilding-libgcc.  */"] + t.predefines,
        "libgcc_tm.h": ["#ifndef LIBGCC_TM_H", "#define LIBGCC_TM_H"] +
                       ["#include \"{}\"".format(h) for h in t.libgcc_tm_file] +
                       ["#endif /* LIBGCC_TM_H */"],
        "options.h": ["/* Stand-in for GCC's generated options.h.  */"],
        "tconfig.h": _TCONFIG_H,
        "tm.h": _mkconfig_tm_h(t.tm_defines, t.tm_file),
    }

def libgcc_header_links(cpu, version):
    """Lists Makefile.in's LIBGCC_LINKS and the other copied headers.

    Returns:
      A dict from each copy's name to its source path in the GCC repository.
      Fails for a version or CPU that is not ported.
    """
    t = _target(cpu, version)
    links = {
        "enable-execute-stack.c": "libgcc/enable-execute-stack-empty.c",
        "gthr-default.h": "libgcc/gthr-posix.h",
        "md-unwind-support.h": t.md_unwind_header,
        "sfp-machine.h": t.sfp_machine_header,
        "unwind.h": "libgcc/unwind-generic.h",
    }
    if t.md_unwind_def_header:
        links["md-unwind-def.h"] = t.md_unwind_def_header
    links.update(t.extra_links)
    return links

def libgcc_target_triple(cpu, version):
    return _target(cpu, version).triple

def libgcc_configure_results(cpu, version):
    """The config.gcc and config.host results this configuration encodes.

    //runtimes/libgcc/tests:configure_* runs those scripts and compares their
    results with these.

    Returns:
      A dict from each configure variable to its value, with paths written
      as configure writes them: tm_file relative to gcc/config, the libgcc
      headers relative to libgcc/config and the other files relative to
      libgcc.
    """
    t = _target(cpu, version)
    links = libgcc_header_links(cpu, version)
    return {
        "enable_execute_stack": links["enable-execute-stack.c"].removeprefix("libgcc/"),
        "libgcc_tm_file": " ".join([f.removeprefix("config/") for f in t.libgcc_tm_file]),
        "md_unwind_def_header": links.get("md-unwind-def.h", "").removeprefix("libgcc/config/"),
        "md_unwind_header": links["md-unwind-support.h"].removeprefix("libgcc/config/"),
        "sfp_machine_header": links["sfp-machine.h"].removeprefix("libgcc/config/"),
        "thread_header": links["gthr-default.h"].removeprefix("libgcc/"),
        "tm_defines": " ".join(t.tm_defines),
        "tm_file": " ".join([f.removeprefix("config/") for f in t.tm_file]),
        "unwind_header": links["unwind.h"].removeprefix("libgcc/"),
    }

def libgcc_target_copts(cpu, version):
    return _target(cpu, version).copts

def libgcc_shlib_mapfiles(cpu, version):
    """SHLIB_MAPFILES after libgcc-std.ver, from the target's tmake fragments."""
    return _target(cpu, version).shlib_mapfiles
