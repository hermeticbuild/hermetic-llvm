load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_static_library.bzl", "cc_stage2_static_library")

# -----------------------------------------------------------------------------
# Makefile-ish configuration (via --define)
# -----------------------------------------------------------------------------

config_setting(
    name = "wasi_p1",
    values = {"define": "wasi_snapshot=p1"},
)

config_setting(
    name = "wasi_p2",
    values = {"define": "wasi_snapshot=p2"},
)

config_setting(
    name = "thread_single",
    values = {"define": "thread_model=single"},
)

config_setting(
    name = "thread_posix",
    values = {"define": "thread_model=posix"},
)

config_setting(
    name = "malloc_dlmalloc",
    values = {"define": "malloc_impl=dlmalloc"},
)

config_setting(
    name = "malloc_emmalloc",
    values = {"define": "malloc_impl=emmalloc"},
)

config_setting(
    name = "malloc_none",
    values = {"define": "malloc_impl=none"},
)

config_setting(
    name = "build_top_half_yes",
    values = {"define": "build_libc_top_half=yes"},
)

config_setting(
    name = "build_top_half_no",
    values = {"define": "build_libc_top_half=no"},
)

config_setting(
    name = "build_libsetjmp_yes",
    values = {"define": "build_libsetjmp=yes"},
)

config_setting(
    name = "build_libsetjmp_no",
    values = {"define": "build_libsetjmp=no"},
)

REPO_ROOT = "external/+wasi+wasi_libc"

# -----------------------------------------------------------------------------
# Common flags (maps to the Makefile's warning + wasi knobs)
# -----------------------------------------------------------------------------

TARGET_TRIPLE_COPTS = select({
    ":wasi_p2": ["--target=wasm32-wasip2"],
    ":thread_posix": ["--target=wasm32-wasip1-threads"],
    "//conditions:default": ["--target=wasm32-wasi"],
})

COMMON_COPTS = TARGET_TRIPLE_COPTS + [
    "-fno-trapping-math",
    "-Wall",
    "-Wextra",
    "-Werror",
    "-Wno-null-pointer-arithmetic",
    "-Wno-unused-parameter",
    "-Wno-sign-compare",
    "-Wno-unused-variable",
    "-Wno-unused-function",
    "-Wno-ignored-attributes",
    "-Wno-missing-braces",
    "-Wno-ignored-pragmas",
    "-Wno-unused-but-set-variable",
    "-Wno-unknown-warning-option",
    "-Wno-unterminated-string-initialization",
    "-Wno-unused-command-line-argument",
    "-Wno-error=bitwise-op-parentheses",
    "-Wno-error=shift-op-parentheses",
    "-Wno-macro-redefined",
]

BOTTOM_HALF_PREINCLUDES = [
    # Upstream relies on these to provide __arraycount, off_t, and other
    # cloudlibc helpers without patching sources.
    "-include",
    REPO_ROOT + "/libc-bottom-half/cloudlibc/src/include/_/cdefs.h",
    "-include",
    REPO_ROOT + "/libc-bottom-half/headers/public/__typedef_off_t.h",
]

THREAD_SINGLE_COPTS = [
    # matches Makefile's -mthread-model single
    "-mthread-model",
    "single",
]

THREAD_POSIX_COPTS = [
    # matches Makefile's -mthread-model posix -pthread -ftls-model=local-exec
    "-mthread-model",
    "posix",
    "-pthread",
    "-ftls-model=local-exec",
]

THREAD_MODEL_COPTS = select({
    ":thread_single": THREAD_SINGLE_COPTS,
    ":thread_posix": THREAD_POSIX_COPTS,
    "//conditions:default": THREAD_SINGLE_COPTS,
})

# Extra warning disables used for top-half + friends
TOP_HALF_EXTRA_COPTS = [
    "-Wno-parentheses",
    "-Wno-shift-op-parentheses",
    "-Wno-bitwise-op-parentheses",
    "-Wno-logical-op-parentheses",
    "-Wno-string-plus-int",
    "-Wno-dangling-else",
    "-Wno-unknown-pragmas",
]

# WASIp2 defines (Makefile adds -D__wasilibc_use_wasip2)
WASI_P2_DEFINES = ["__wasilibc_use_wasip2"]

WASI_P2_COPTS = select({
    ":wasi_p2": ["-D" + d for d in WASI_P2_DEFINES],
    "//conditions:default": [],
})

# Bulk-memory flags apply only to a few string files (Makefile does per-target)
BULK_MEMORY_COPTS = [
    "-mbulk-memory",
    # Makefile also sets -DBULK_MEMORY_THRESHOLD=... (default 32).
    # Provide this via --copt=-DBULK_MEMORY_THRESHOLD=32 if you want.
]

TOP_HALF_BASE_COPTS = COMMON_COPTS + TOP_HALF_EXTRA_COPTS + THREAD_MODEL_COPTS + WASI_P2_COPTS

MUSL_ARCH_INCLUDES = [
    "libc-top-half/musl/arch/wasm32",
    "libc-top-half/musl/arch/generic",
]

TOP_HALF_INCLUDES = [
    # Matches Makefile include dirs for top-half compilation
    "libc-top-half/musl/src/include",
    "libc-top-half/musl/src/internal",
    "libc-top-half/musl/include",
    "libc-bottom-half/headers/public",
    "libc-bottom-half/cloudlibc/src",
    "libc-top-half/headers/private",
]

BOTTOM_HALF_INCLUDES = [
    "libc-top-half/musl/src/include",
    "libc-top-half/musl/include",
    "libc-top-half/musl/src/internal",
    # Match Makefile include dirs for bottom-half compilation
    "libc-bottom-half/headers/public",
    "libc-bottom-half/headers/private",
    "libc-bottom-half/cloudlibc/src/include",
    "libc-bottom-half/cloudlibc/src/common",
    "libc-bottom-half/cloudlibc/src",
]

BOTTOM_HALF_INCLUDES_NO_PRIVATE = [
    "libc-top-half/musl/src/include",
    "libc-top-half/musl/include",
    "libc-top-half/musl/src/internal",
    "libc-bottom-half/headers/public",
    "libc-bottom-half/cloudlibc/src/include",
    "libc-bottom-half/cloudlibc/src/common",
    "libc-bottom-half/cloudlibc/src",
]

WASI_EMULATED_SIGNAL_INCLUDES = TOP_HALF_INCLUDES + [
    "libc-bottom-half/headers/private",
    "libc-bottom-half/cloudlibc/src/include",
    "libc-bottom-half/cloudlibc/src/common",
]

# setjmp sjlj flags
LIBSETJMP_COPTS = [
    "-mllvm",
    "-wasm-enable-sjlj",
]

# -----------------------------------------------------------------------------
# Headers (public/private) - surfaced as hdrs; include paths are handled via
# includes to match Makefile.
# -----------------------------------------------------------------------------

filegroup(
    name = "libc_bottom_half_headers_public",
    srcs = glob(["libc-bottom-half/headers/public/**/*.h"]),
)

filegroup(
    name = "libc_bottom_half_headers_private",
    srcs = glob(["libc-bottom-half/headers/private/**/*.h"]),
)

filegroup(
    name = "cloudlibc_headers",
    srcs = glob([
        "libc-bottom-half/cloudlibc/src/include/**/*.h",
        "libc-bottom-half/cloudlibc/src/common/**/*.h",
        "libc-bottom-half/cloudlibc/src/libc/**/*.h",
    ]),
)

filegroup(
    name = "libc_top_half_headers_private",
    srcs = glob(["libc-top-half/headers/private/**/*.h"]),
)

filegroup(
    name = "musl_headers",
    srcs = glob([
        "libc-top-half/musl/include/**/*.h",
        "libc-top-half/musl/arch/wasm32/**/*.h",
        "libc-top-half/musl/arch/generic/**/*.h",
        "libc-top-half/musl/src/internal/**/*.h",
        "libc-top-half/musl/src/include/**/*.h",
        "libc-top-half/musl/src/**/*.h",
    ]) + [":generate_bits_alltypes"],
)

genrule(
    name = "generate_bits_alltypes",
    srcs = [
        "libc-top-half/musl/tools/mkalltypes.sed",
        "libc-top-half/musl/arch/wasm32/bits/alltypes.h.in",
        "libc-top-half/musl/include/alltypes.h.in",
    ],
    outs = ["libc-top-half/musl/arch/wasm32/bits/alltypes.h"],
    cmd = """sed -f $(location libc-top-half/musl/tools/mkalltypes.sed) \
$(location libc-top-half/musl/arch/wasm32/bits/alltypes.h.in) \
$(location libc-top-half/musl/include/alltypes.h.in) > $@ && cat >>$@ <<'EOF'
#if defined(__NEED_wchar_t)
#undef __DEFINED_wchar_t
typedef __WCHAR_TYPE__ wchar_t;
#define __DEFINED_wchar_t
#endif
#if defined(__NEED_wint_t)
#undef __DEFINED_wint_t
typedef __WINT_TYPE__ wint_t;
#define __DEFINED_wint_t
#endif
EOF""",
    visibility = ["//visibility:private"],
)

filegroup(
    name = "fts_headers",
    srcs = glob(["fts/**/*.h"]),
)

write_file(
    name = "weak_macro_shim",
    out = "wasi-build-weak-shim.h",
    content = [
        "#pragma once",
        "#include \"libc-top-half/musl/src/include/features.h\"",
        "#undef weak",
        "#define weak __weak__",
    ],
    visibility = ["//visibility:private"],
)

# -----------------------------------------------------------------------------
# malloc implementations (dlmalloc / emmalloc / none)
# -----------------------------------------------------------------------------

filegroup(
    name = "dlmalloc_sources",
    srcs = ["dlmalloc/src/dlmalloc.c"],
)

filegroup(
    name = "emmalloc_sources",
    srcs = ["emmalloc/emmalloc.c"],
)

cc_stage2_library(
    name = "dlmalloc",
    srcs = [":dlmalloc_sources"],
    hdrs = glob(["dlmalloc/include/**/*.h"]) + [
        ":musl_headers",
        ":libc_bottom_half_headers_public",
    ],
    includes = MUSL_ARCH_INCLUDES + TOP_HALF_INCLUDES + [
        "dlmalloc/include",
    ],
    textual_hdrs = ["dlmalloc/src/malloc.c"],
    copts = TOP_HALF_BASE_COPTS + [
        "-Wno-macro-redefined",
    ],
)

cc_stage2_library(
    name = "emmalloc",
    srcs = [":emmalloc_sources"],
    hdrs = [
        ":musl_headers",
        ":libc_bottom_half_headers_public",
    ],
    includes = MUSL_ARCH_INCLUDES + TOP_HALF_INCLUDES,
    # emmalloc has UB aliasing patterns; Makefile uses -fno-strict-aliasing
    copts = TOP_HALF_BASE_COPTS + [
        "-fno-strict-aliasing",
    ],
)

cc_stage2_library(
    name = "malloc_impl",
    deps = select({
        ":malloc_dlmalloc": [":dlmalloc"],
        ":malloc_emmalloc": [":emmalloc"],
        ":malloc_none": [],
        "//conditions:default": [":dlmalloc"],
    }),
)

# -----------------------------------------------------------------------------
# fts
# -----------------------------------------------------------------------------

filegroup(
    name = "fts_sources",
    srcs = ["fts/musl-fts/fts.c"],
)

cc_stage2_library(
    name = "fts",
    srcs = [":fts_sources"],
    hdrs = [
        ":fts_headers",
        ":musl_headers",
        ":libc_bottom_half_headers_public",
    ],
    includes = MUSL_ARCH_INCLUDES + TOP_HALF_INCLUDES + [
        # Makefile: -I$(MUSL_FTS_SRC_DIR) -I$(FTS_SRC_DIR)
        "fts/musl-fts",
        "fts",
    ],
    copts = TOP_HALF_BASE_COPTS,
)

# -----------------------------------------------------------------------------
# libc-bottom-half sources
# -----------------------------------------------------------------------------

# “find”-equivalent: all .c from cloudlibc/src and libc-bottom-half/sources
# then exclude per snapshot.
BOTTOM_HALF_ALL_C = glob([
    "libc-bottom-half/cloudlibc/src/**/*.c",
    "libc-bottom-half/sources/**/*.c",
])

BOTTOM_HALF_OMIT_P1 = [
    "libc-bottom-half/sources/wasip2.c",
    "libc-bottom-half/sources/descriptor_table.c",
    "libc-bottom-half/sources/connect.c",
    "libc-bottom-half/sources/socket.c",
    "libc-bottom-half/sources/send.c",
    "libc-bottom-half/sources/recv.c",
    "libc-bottom-half/sources/sockets_utils.c",
    "libc-bottom-half/sources/bind.c",
    "libc-bottom-half/sources/listen.c",
    "libc-bottom-half/sources/accept-wasip2.c",
    "libc-bottom-half/sources/shutdown.c",
    "libc-bottom-half/sources/sockopt.c",
    "libc-bottom-half/sources/poll-wasip2.c",
    "libc-bottom-half/sources/getsockpeername.c",
    "libc-bottom-half/sources/netdb.c",
]

BOTTOM_HALF_OMIT_P2 = [
    "libc-bottom-half/cloudlibc/src/libc/sys/socket/send.c",
    "libc-bottom-half/cloudlibc/src/libc/sys/socket/recv.c",
    "libc-bottom-half/cloudlibc/src/libc/sys/socket/shutdown.c",
    "libc-bottom-half/cloudlibc/src/libc/sys/socket/getsockopt.c",
    "libc-bottom-half/sources/accept-wasip1.c",
]

filegroup(
    name = "libc_bottom_half_sources",
    srcs = select({
        ":wasi_p1": [s for s in BOTTOM_HALF_ALL_C if s not in BOTTOM_HALF_OMIT_P1],
        ":wasi_p2": [s for s in BOTTOM_HALF_ALL_C if s not in BOTTOM_HALF_OMIT_P2],
        "//conditions:default": [s for s in BOTTOM_HALF_ALL_C if s not in BOTTOM_HALF_OMIT_P1],
    }),
)

# crt sources exist, but Makefile “installs” them into sysroot; we just build them
# as an internal library in case you want to depend on them later.
filegroup(
    name = "libc_bottom_half_crt_sources",
    srcs = glob(["libc-bottom-half/crt/*.c"]),
)

cc_stage2_library(
    name = "libc_bottom_half",
    srcs = [":libc_bottom_half_sources"],
    hdrs = [
        ":libc_bottom_half_headers_public",
        ":libc_bottom_half_headers_private",
        ":cloudlibc_headers",
        ":musl_headers",  # Makefile includes musl internal/include for some bottom-half files
    ],
    includes = MUSL_ARCH_INCLUDES + BOTTOM_HALF_INCLUDES,
    copts = COMMON_COPTS + THREAD_MODEL_COPTS + WASI_P2_COPTS + BOTTOM_HALF_PREINCLUDES,
)

cc_stage2_library(
    name = "libc_crt",
    srcs = [":libc_bottom_half_crt_sources"],
    hdrs = [
        ":libc_bottom_half_headers_public",
        ":libc_bottom_half_headers_private",
        ":cloudlibc_headers",
        ":musl_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + BOTTOM_HALF_INCLUDES,
    copts = COMMON_COPTS + TOP_HALF_EXTRA_COPTS + THREAD_MODEL_COPTS + WASI_P2_COPTS,
)

# -----------------------------------------------------------------------------
# libc-top-half (musl + local sources + thread stubs)
# -----------------------------------------------------------------------------

# This is the explicit Makefile list for musl sources (kept as-is).
filegroup(
    name = "libc_top_half_musl_sources_explicit",
    srcs = [
        # Copy/paste of Makefile’s explicit addprefix list:
        "libc-top-half/musl/src/misc/a64l.c",
        "libc-top-half/musl/src/misc/basename.c",
        "libc-top-half/musl/src/misc/dirname.c",
        "libc-top-half/musl/src/misc/ffs.c",
        "libc-top-half/musl/src/misc/ffsl.c",
        "libc-top-half/musl/src/misc/ffsll.c",
        "libc-top-half/musl/src/misc/fmtmsg.c",
        "libc-top-half/musl/src/misc/getdomainname.c",
        "libc-top-half/musl/src/misc/gethostid.c",
        "libc-top-half/musl/src/misc/getopt.c",
        "libc-top-half/musl/src/misc/getopt_long.c",
        "libc-top-half/musl/src/misc/getsubopt.c",
        "libc-top-half/musl/src/misc/realpath.c",
        "libc-top-half/musl/src/misc/uname.c",
        "libc-top-half/musl/src/misc/nftw.c",
        "libc-top-half/musl/src/errno/strerror.c",
        "libc-top-half/musl/src/network/htonl.c",
        "libc-top-half/musl/src/network/htons.c",
        "libc-top-half/musl/src/network/ntohl.c",
        "libc-top-half/musl/src/network/ntohs.c",
        "libc-top-half/musl/src/network/inet_ntop.c",
        "libc-top-half/musl/src/network/inet_pton.c",
        "libc-top-half/musl/src/network/inet_aton.c",
        "libc-top-half/musl/src/network/in6addr_any.c",
        "libc-top-half/musl/src/network/in6addr_loopback.c",
        "libc-top-half/musl/src/fenv/fenv.c",
        "libc-top-half/musl/src/fenv/fesetround.c",
        "libc-top-half/musl/src/fenv/feupdateenv.c",
        "libc-top-half/musl/src/fenv/fesetexceptflag.c",
        "libc-top-half/musl/src/fenv/fegetexceptflag.c",
        "libc-top-half/musl/src/fenv/feholdexcept.c",
        "libc-top-half/musl/src/exit/exit.c",
        "libc-top-half/musl/src/exit/atexit.c",
        "libc-top-half/musl/src/exit/assert.c",
        "libc-top-half/musl/src/exit/quick_exit.c",
        "libc-top-half/musl/src/exit/at_quick_exit.c",
        "libc-top-half/musl/src/time/strftime.c",
        "libc-top-half/musl/src/time/asctime.c",
        "libc-top-half/musl/src/time/asctime_r.c",
        "libc-top-half/musl/src/time/ctime.c",
        "libc-top-half/musl/src/time/ctime_r.c",
        "libc-top-half/musl/src/time/wcsftime.c",
        "libc-top-half/musl/src/time/strptime.c",
        "libc-top-half/musl/src/time/difftime.c",
        "libc-top-half/musl/src/time/timegm.c",
        "libc-top-half/musl/src/time/ftime.c",
        "libc-top-half/musl/src/time/gmtime.c",
        "libc-top-half/musl/src/time/gmtime_r.c",
        "libc-top-half/musl/src/time/timespec_get.c",
        "libc-top-half/musl/src/time/getdate.c",
        "libc-top-half/musl/src/time/localtime.c",
        "libc-top-half/musl/src/time/localtime_r.c",
        "libc-top-half/musl/src/time/mktime.c",
        "libc-top-half/musl/src/time/__tm_to_secs.c",
        "libc-top-half/musl/src/time/__month_to_secs.c",
        "libc-top-half/musl/src/time/__secs_to_tm.c",
        "libc-top-half/musl/src/time/__year_to_secs.c",
        "libc-top-half/musl/src/time/__tz.c",
        "libc-top-half/musl/src/fcntl/creat.c",
        "libc-top-half/musl/src/dirent/alphasort.c",
        "libc-top-half/musl/src/dirent/versionsort.c",
        "libc-top-half/musl/src/env/__stack_chk_fail.c",
        "libc-top-half/musl/src/env/clearenv.c",
        "libc-top-half/musl/src/env/getenv.c",
        "libc-top-half/musl/src/env/putenv.c",
        "libc-top-half/musl/src/env/setenv.c",
        "libc-top-half/musl/src/env/unsetenv.c",
        "libc-top-half/musl/src/unistd/posix_close.c",
        "libc-top-half/musl/src/stat/futimesat.c",
        "libc-top-half/musl/src/legacy/getpagesize.c",
        "libc-top-half/musl/src/thread/thrd_sleep.c",
    ],
)

# Globs with Makefile-style filter-outs. This mirrors:
# - internal/*.c minus procfdname.c syscall*.c vdso.c version.c emulate_wait4.c
# - stdio/*.c minus (flockfile/funlockfile/__lockfile/ftrylockfile, rename, tmp*, popen/pclose, remove, gets)
# - string/*.c minus strsignal.c
# - locale/*.c minus dcngettext.c textdomain.c bind_textdomain_codeset.c
# - lots of globs kept
# - math/*.c minus various fp helpers and common ops
# - complex/*.c minus creal/cimag variants
filegroup(
    name = "libc_top_half_musl_sources_globbed",
    srcs = glob(["libc-top-half/musl/src/internal/*.c"], exclude = [
        "libc-top-half/musl/src/internal/procfdname.c",
        "libc-top-half/musl/src/internal/syscall.c",
        "libc-top-half/musl/src/internal/syscall_ret.c",
        "libc-top-half/musl/src/internal/vdso.c",
        "libc-top-half/musl/src/internal/version.c",
        "libc-top-half/musl/src/internal/emulate_wait4.c",
    ]) +
    glob(["libc-top-half/musl/src/stdio/*.c"], exclude = [
        "libc-top-half/musl/src/stdio/flockfile.c",
        "libc-top-half/musl/src/stdio/funlockfile.c",
        "libc-top-half/musl/src/stdio/__lockfile.c",
        "libc-top-half/musl/src/stdio/ftrylockfile.c",
        "libc-top-half/musl/src/stdio/rename.c",
        "libc-top-half/musl/src/stdio/tmpnam.c",
        "libc-top-half/musl/src/stdio/tmpfile.c",
        "libc-top-half/musl/src/stdio/tempnam.c",
        "libc-top-half/musl/src/stdio/popen.c",
        "libc-top-half/musl/src/stdio/pclose.c",
        "libc-top-half/musl/src/stdio/remove.c",
        "libc-top-half/musl/src/stdio/gets.c",
    ]) +
    glob(["libc-top-half/musl/src/string/*.c"], exclude = [
        "libc-top-half/musl/src/string/strsignal.c",
        "libc-top-half/musl/src/string/memcpy.c",
        "libc-top-half/musl/src/string/memmove.c",
        "libc-top-half/musl/src/string/memset.c",
    ]) +
    glob(["libc-top-half/musl/src/locale/*.c"], exclude = [
        "libc-top-half/musl/src/locale/dcngettext.c",
        "libc-top-half/musl/src/locale/textdomain.c",
        "libc-top-half/musl/src/locale/bind_textdomain_codeset.c",
    ]) +
    glob(["libc-top-half/musl/src/stdlib/*.c"]) +
    glob(["libc-top-half/musl/src/search/*.c"]) +
    glob(["libc-top-half/musl/src/multibyte/*.c"]) +
    glob(["libc-top-half/musl/src/regex/*.c"]) +
    glob(["libc-top-half/musl/src/prng/*.c"]) +
    glob(["libc-top-half/musl/src/conf/*.c"]) +
    glob(["libc-top-half/musl/src/ctype/*.c"]) +
    glob(["libc-top-half/musl/src/math/*.c"], exclude = [
        "libc-top-half/musl/src/math/__signbit.c",
        "libc-top-half/musl/src/math/__signbitf.c",
        "libc-top-half/musl/src/math/__signbitl.c",
        "libc-top-half/musl/src/math/__fpclassify.c",
        "libc-top-half/musl/src/math/__fpclassifyf.c",
        "libc-top-half/musl/src/math/__fpclassifyl.c",
        "libc-top-half/musl/src/math/ceilf.c",
        "libc-top-half/musl/src/math/ceil.c",
        "libc-top-half/musl/src/math/floorf.c",
        "libc-top-half/musl/src/math/floor.c",
        "libc-top-half/musl/src/math/truncf.c",
        "libc-top-half/musl/src/math/trunc.c",
        "libc-top-half/musl/src/math/rintf.c",
        "libc-top-half/musl/src/math/rint.c",
        "libc-top-half/musl/src/math/nearbyintf.c",
        "libc-top-half/musl/src/math/nearbyint.c",
        "libc-top-half/musl/src/math/sqrtf.c",
        "libc-top-half/musl/src/math/sqrt.c",
        "libc-top-half/musl/src/math/fabsf.c",
        "libc-top-half/musl/src/math/fabs.c",
        "libc-top-half/musl/src/math/copysignf.c",
        "libc-top-half/musl/src/math/copysign.c",
        "libc-top-half/musl/src/math/fminf.c",
        "libc-top-half/musl/src/math/fmaxf.c",
        "libc-top-half/musl/src/math/fmin.c",
        "libc-top-half/musl/src/math/fmax.c",
    ]) +
    glob(["libc-top-half/musl/src/complex/*.c"], exclude = [
        "libc-top-half/musl/src/complex/crealf.c",
        "libc-top-half/musl/src/complex/creal.c",
        "libc-top-half/musl/src/complex/creall.c",
        "libc-top-half/musl/src/complex/cimagf.c",
        "libc-top-half/musl/src/complex/cimag.c",
        "libc-top-half/musl/src/complex/cimagl.c",
    ]) +
    glob(["libc-top-half/musl/src/crypt/*.c"]),
)

# WASIp2 adds gai_strerror.c
filegroup(
    name = "libc_top_half_musl_sources_wasi_p2_extra",
    srcs = ["libc-top-half/musl/src/network/gai_strerror.c"],
)

# Common pthread API files (Makefile adds them for both models)
filegroup(
    name = "libc_top_half_pthread_common_sources",
    srcs = [
        "libc-top-half/musl/src/env/__init_tls.c",
        "libc-top-half/musl/src/thread/default_attr.c",
        "libc-top-half/musl/src/thread/pthread_attr_destroy.c",
        "libc-top-half/musl/src/thread/pthread_attr_get.c",
        "libc-top-half/musl/src/thread/pthread_attr_init.c",
        "libc-top-half/musl/src/thread/pthread_attr_setdetachstate.c",
        "libc-top-half/musl/src/thread/pthread_attr_setguardsize.c",
        "libc-top-half/musl/src/thread/pthread_attr_setschedparam.c",
        "libc-top-half/musl/src/thread/pthread_attr_setstack.c",
        "libc-top-half/musl/src/thread/pthread_attr_setstacksize.c",
        "libc-top-half/musl/src/thread/pthread_barrierattr_destroy.c",
        "libc-top-half/musl/src/thread/pthread_barrierattr_init.c",
        "libc-top-half/musl/src/thread/pthread_barrierattr_setpshared.c",
        "libc-top-half/musl/src/thread/pthread_cancel.c",
        "libc-top-half/musl/src/thread/pthread_cleanup_push.c",
        "libc-top-half/musl/src/thread/pthread_condattr_destroy.c",
        "libc-top-half/musl/src/thread/pthread_condattr_init.c",
        "libc-top-half/musl/src/thread/pthread_condattr_setclock.c",
        "libc-top-half/musl/src/thread/pthread_condattr_setpshared.c",
        "libc-top-half/musl/src/thread/pthread_equal.c",
        "libc-top-half/musl/src/thread/pthread_getattr_np.c",
        "libc-top-half/musl/src/thread/pthread_getspecific.c",
        "libc-top-half/musl/src/thread/pthread_key_create.c",
        "libc-top-half/musl/src/thread/pthread_mutex_destroy.c",
        "libc-top-half/musl/src/thread/pthread_mutex_init.c",
        "libc-top-half/musl/src/thread/pthread_mutexattr_destroy.c",
        "libc-top-half/musl/src/thread/pthread_mutexattr_init.c",
        "libc-top-half/musl/src/thread/pthread_mutexattr_setprotocol.c",
        "libc-top-half/musl/src/thread/pthread_mutexattr_setpshared.c",
        "libc-top-half/musl/src/thread/pthread_mutexattr_setrobust.c",
        "libc-top-half/musl/src/thread/pthread_mutexattr_settype.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_destroy.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_init.c",
        "libc-top-half/musl/src/thread/pthread_rwlockattr_destroy.c",
        "libc-top-half/musl/src/thread/pthread_rwlockattr_init.c",
        "libc-top-half/musl/src/thread/pthread_rwlockattr_setpshared.c",
        "libc-top-half/musl/src/thread/pthread_self.c",
        "libc-top-half/musl/src/thread/pthread_setcancelstate.c",
        "libc-top-half/musl/src/thread/pthread_setcanceltype.c",
        "libc-top-half/musl/src/thread/pthread_setspecific.c",
        "libc-top-half/musl/src/thread/pthread_spin_destroy.c",
        "libc-top-half/musl/src/thread/pthread_spin_init.c",
        "libc-top-half/musl/src/thread/pthread_testcancel.c",
    ],
)

filegroup(
    name = "libc_top_half_pthread_posix_sources",
    srcs = [
        "libc-top-half/musl/src/stdio/__lockfile.c",
        "libc-top-half/musl/src/stdio/flockfile.c",
        "libc-top-half/musl/src/stdio/ftrylockfile.c",
        "libc-top-half/musl/src/stdio/funlockfile.c",
        "libc-top-half/musl/src/thread/__lock.c",
        "libc-top-half/musl/src/thread/__wait.c",
        "libc-top-half/musl/src/thread/__timedwait.c",
        "libc-top-half/musl/src/thread/pthread_barrier_destroy.c",
        "libc-top-half/musl/src/thread/pthread_barrier_init.c",
        "libc-top-half/musl/src/thread/pthread_barrier_wait.c",
        "libc-top-half/musl/src/thread/pthread_cond_broadcast.c",
        "libc-top-half/musl/src/thread/pthread_cond_destroy.c",
        "libc-top-half/musl/src/thread/pthread_cond_init.c",
        "libc-top-half/musl/src/thread/pthread_cond_signal.c",
        "libc-top-half/musl/src/thread/pthread_cond_timedwait.c",
        "libc-top-half/musl/src/thread/pthread_cond_wait.c",
        "libc-top-half/musl/src/thread/pthread_create.c",
        "libc-top-half/musl/src/thread/pthread_detach.c",
        "libc-top-half/musl/src/thread/pthread_join.c",
        "libc-top-half/musl/src/thread/pthread_mutex_consistent.c",
        "libc-top-half/musl/src/thread/pthread_mutex_getprioceiling.c",
        "libc-top-half/musl/src/thread/pthread_mutex_lock.c",
        "libc-top-half/musl/src/thread/pthread_mutex_timedlock.c",
        "libc-top-half/musl/src/thread/pthread_mutex_trylock.c",
        "libc-top-half/musl/src/thread/pthread_mutex_unlock.c",
        "libc-top-half/musl/src/thread/pthread_once.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_rdlock.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_timedrdlock.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_timedwrlock.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_tryrdlock.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_trywrlock.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_unlock.c",
        "libc-top-half/musl/src/thread/pthread_rwlock_wrlock.c",
        "libc-top-half/musl/src/thread/pthread_spin_lock.c",
        "libc-top-half/musl/src/thread/pthread_spin_trylock.c",
        "libc-top-half/musl/src/thread/pthread_spin_unlock.c",
        "libc-top-half/musl/src/thread/sem_destroy.c",
        "libc-top-half/musl/src/thread/sem_getvalue.c",
        "libc-top-half/musl/src/thread/sem_init.c",
        "libc-top-half/musl/src/thread/sem_post.c",
        "libc-top-half/musl/src/thread/sem_timedwait.c",
        "libc-top-half/musl/src/thread/sem_trywait.c",
        "libc-top-half/musl/src/thread/sem_wait.c",
        "libc-top-half/musl/src/thread/wasm32/wasi_thread_start.s",
        "libc-top-half/musl/src/thread/wasm32/__wasilibc_busywait.c",
    ],
)

filegroup(
    name = "libc_top_half_pthread_single_stub_sources",
    srcs = glob(["thread-stub/*.c"]),
)

filegroup(
    name = "libc_top_half_local_sources",
    srcs = glob(["libc-top-half/sources/**/*.c"]),
)

filegroup(
    name = "libc_top_half_all_sources",
    srcs =
        [":libc_top_half_musl_sources_explicit"] +
        [":libc_top_half_musl_sources_globbed"] +
        select({
            ":wasi_p2": [":libc_top_half_musl_sources_wasi_p2_extra"],
            "//conditions:default": [],
        }) +
        [":libc_top_half_pthread_common_sources"] +
        select({
            ":thread_posix": [":libc_top_half_pthread_posix_sources"],
            ":thread_single": [":libc_top_half_pthread_single_stub_sources"],
            "//conditions:default": [":libc_top_half_pthread_single_stub_sources"],
        }) +
        [":libc_top_half_local_sources"],
)

# Special subsets used for per-file flags.
BULK_MEMORY_SRCS = [
    "libc-top-half/musl/src/string/memcpy.c",
    "libc-top-half/musl/src/string/memmove.c",
    "libc-top-half/musl/src/string/memset.c",
]

LIBSETJMP_SRCS = [
    "libc-top-half/musl/src/setjmp/wasm32/rt.c",
]

WASI_EMULATED_SIGNAL_MUSL_SRCS = [
    "libc-top-half/musl/src/signal/psignal.c",
    "libc-top-half/musl/src/string/strsignal.c",
]

cc_stage2_library(
    name = "libc_top_half",
    srcs = select({
        ":build_top_half_yes": [":libc_top_half_all_sources"],
        ":build_top_half_no": [],
        "//conditions:default": [":libc_top_half_all_sources"],
    }),
    hdrs = [
        ":musl_headers",
        ":libc_top_half_headers_private",
        ":libc_bottom_half_headers_public",
        ":cloudlibc_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + TOP_HALF_INCLUDES,
    copts = TOP_HALF_BASE_COPTS,
    deps = select({
        ":build_top_half_yes": [":libc_top_half_bulk_memory"],
        ":build_top_half_no": [],
        "//conditions:default": [":libc_top_half_bulk_memory"],
    }),
)

cc_stage2_library(
    name = "libc_top_half_bulk_memory",
    srcs = BULK_MEMORY_SRCS,
    hdrs = [
        ":musl_headers",
        ":libc_top_half_headers_private",
        ":libc_bottom_half_headers_public",
        ":cloudlibc_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + TOP_HALF_INCLUDES,
    copts = TOP_HALF_BASE_COPTS + BULK_MEMORY_COPTS + [
        # Match Makefile default BULK_MEMORY_THRESHOLD
        "-DBULK_MEMORY_THRESHOLD=32",
    ],
)

# -----------------------------------------------------------------------------
# “deps” libs the Makefile emitted as separate archives (optional, but handy)
# -----------------------------------------------------------------------------

# libdl = musl misc/dl.c
cc_stage2_library(
    name = "libdl",
    srcs = ["libc-top-half/musl/src/misc/dl.c"],
    hdrs = [
        ":musl_headers",
        ":libc_top_half_headers_private",
        ":libc_bottom_half_headers_public",
        ":cloudlibc_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + TOP_HALF_INCLUDES,
    copts = TOP_HALF_BASE_COPTS,
)

# libsetjmp = musl setjmp/wasm32/rt.c (Makefile can disable)
cc_stage2_library(
    name = "libsetjmp",
    srcs = select({
        ":build_libsetjmp_yes": LIBSETJMP_SRCS,
        ":build_libsetjmp_no": [],
        "//conditions:default": LIBSETJMP_SRCS,
    }),
    hdrs = [
        ":musl_headers",
        ":libc_top_half_headers_private",
        ":libc_bottom_half_headers_public",
        ":cloudlibc_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + TOP_HALF_INCLUDES,
    copts = TOP_HALF_BASE_COPTS + LIBSETJMP_COPTS,
)

# wasi-emulated-* sources are in libc-bottom-half subdirs
cc_stage2_library(
    name = "libwasi_emulated_mman",
    srcs = glob(["libc-bottom-half/mman/*.c"]),
    hdrs = [
        ":libc_bottom_half_headers_public",
        ":libc_bottom_half_headers_private",
        ":cloudlibc_headers",
        ":musl_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + BOTTOM_HALF_INCLUDES,
    copts = COMMON_COPTS + THREAD_MODEL_COPTS + WASI_P2_COPTS,
)

cc_stage2_library(
    name = "libwasi_emulated_process_clocks",
    srcs = glob(["libc-bottom-half/clocks/*.c"]),
    hdrs = [
        ":libc_bottom_half_headers_public",
        ":libc_bottom_half_headers_private",
        ":cloudlibc_headers",
        ":musl_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + BOTTOM_HALF_INCLUDES_NO_PRIVATE,
    copts = COMMON_COPTS + THREAD_MODEL_COPTS + WASI_P2_COPTS,
)

cc_stage2_library(
    name = "libwasi_emulated_getpid",
    srcs = glob(["libc-bottom-half/getpid/*.c"]),
    hdrs = [
        ":libc_bottom_half_headers_public",
        ":libc_bottom_half_headers_private",
        ":cloudlibc_headers",
        ":musl_headers",
    ],
    includes = MUSL_ARCH_INCLUDES + BOTTOM_HALF_INCLUDES,
    copts = COMMON_COPTS + THREAD_MODEL_COPTS + WASI_P2_COPTS,
)

cc_stage2_library(
    name = "libwasi_emulated_signal",
    srcs = glob(["libc-bottom-half/signal/*.c"]) + WASI_EMULATED_SIGNAL_MUSL_SRCS + [
        ":weak_macro_shim",
    ],
    hdrs = [
        ":libc_bottom_half_headers_public",
        ":libc_bottom_half_headers_private",
        ":cloudlibc_headers",
        ":musl_headers",
        ":weak_macro_shim",
    ],
    includes = MUSL_ARCH_INCLUDES + WASI_EMULATED_SIGNAL_INCLUDES,
    copts = TOP_HALF_BASE_COPTS + [
        "-include",
        "$(location :weak_macro_shim)",
        "-D_WASI_EMULATED_SIGNAL",
    ],
)

cc_stage2_library(
    name = "libc_lib",
    deps = [
        ":malloc_impl",
        ":libc_bottom_half",
        ":fts",
        ":libc_top_half",
        # optional-but-useful “deps” libs
        ":libdl",
        ":libwasi_emulated_mman",
        ":libwasi_emulated_process_clocks",
        ":libwasi_emulated_getpid",
        ":libwasi_emulated_signal",
        ":libsetjmp",
    ],
)

cc_stage2_static_library(
    name = "libc",
    deps = [":libc_lib"],
    visibility = ["//visibility:public"],
)
