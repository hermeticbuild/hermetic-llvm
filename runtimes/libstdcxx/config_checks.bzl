def compile_check(name, source, language = "c", flags = []):
    return struct(
        flags = flags,
        language = language,
        name = name,
        source = source.strip() + "\n",
    )

def link_check(name, source, language = "c++", compile_flags = [], link_flags = []):
    return struct(
        compile_flags = compile_flags,
        language = language,
        link_flags = link_flags,
        name = name,
        source = source.strip() + "\n",
    )

def policy_define(name, value = "1"):
    return struct(
        kind = "define",
        name = name,
        value = value,
    )

def policy_undef(name):
    return struct(
        kind = "undef",
        name = name,
    )

def _header_check(header):
    return compile_check(
        name = "HAVE_" + header.upper().replace("/", "_").replace(".", "_"),
        source = """
#include <{header}>
int main(void) {{ return 0; }}
""".format(header = header),
    )

def _function_link_check(name, header, expression, language = "c++", compile_flags = [], link_flags = []):
    return link_check(
        name = name,
        language = language,
        compile_flags = compile_flags,
        link_flags = link_flags,
        source = """
#include <{header}>
int main() {{
    {expression};
    return 0;
}}
""".format(header = header, expression = expression),
    )

_CXX_FILESYSTEM_FLAGS = ["-fno-exceptions"]
_MATH_LINK_FLAGS = ["-lm"]

_HEADER_CHECKS = [
    "arpa/inet.h",
    "complex.h",
    "debugapi.h",
    "dirent.h",
    "dlfcn.h",
    "endian.h",
    "execinfo.h",
    "fcntl.h",
    "fenv.h",
    "float.h",
    "fp.h",
    "ieeefp.h",
    "inttypes.h",
    "libintl.h",
    "link.h",
    "linux/random.h",
    "linux/types.h",
    "locale.h",
    "machine/endian.h",
    "machine/param.h",
    "memory.h",
    "nan.h",
    "netdb.h",
    "netinet/in.h",
    "netinet/tcp.h",
    "poll.h",
    "stdalign.h",
    "stdbool.h",
    "stdint.h",
    "stdlib.h",
    "string.h",
    "strings.h",
    "sys/filio.h",
    "sys/ioctl.h",
    "sys/ipc.h",
    "sys/isa_defs.h",
    "sys/machine.h",
    "sys/mman.h",
    "sys/param.h",
    "sys/ptrace.h",
    "sys/resource.h",
    "sys/sdt.h",
    "sys/sem.h",
    "sys/socket.h",
    "sys/stat.h",
    "sys/statvfs.h",
    "sys/sysinfo.h",
    "sys/time.h",
    "sys/types.h",
    "sys/uio.h",
    "tgmath.h",
    "tlhelp32.h",
    "uchar.h",
    "unistd.h",
    "utime.h",
    "wchar.h",
    "wctype.h",
    "windows.h",
    "xlocale.h",
]

COMPILE_CHECKS = [_header_check(header) for header in _HEADER_CHECKS] + [
    compile_check(
        name = "HAVE_O_NONBLOCK",
        source = """
#include <fcntl.h>
#ifndef O_NONBLOCK
#error O_NONBLOCK is not defined
#endif
int main(void) { return O_NONBLOCK == 0; }
""",
    ),
    compile_check(
        name = "HAVE_STRUCT_DIRENT_D_TYPE",
        language = "c++",
        flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <dirent.h>
int test(dirent *entry) { return entry->d_type; }
int main(void) { return 0; }
""",
    ),
    compile_check(
        name = "HAVE_S_IFREG",
        source = """
#include <sys/stat.h>
#ifndef S_IFREG
#error S_IFREG is not defined
#endif
int main(void) { return S_IFREG == 0; }
""",
    ),
    compile_check(
        name = "HAVE_S_ISREG",
        source = """
#include <sys/stat.h>
#ifndef S_ISREG
#error S_ISREG is not defined
#endif
int main(void) { return S_ISREG(0); }
""",
    ),
    compile_check(
        name = "HAVE_C99_FLT_EVAL_TYPES",
        language = "c++",
        flags = ["-std=c++11", "-nostdinc++"],
        source = """
#include <math.h>
float_t f;
double_t d;
int main() { return sizeof(f) == sizeof(d); }
""",
    ),
    compile_check(
        name = "HAVE_MBSTATE_T",
        language = "c++",
        flags = ["-nostdinc++"],
        source = """
#include <wchar.h>
mbstate_t state;
int main() { return sizeof(state); }
""",
    ),
    compile_check(
        name = "HAVE_ISWBLANK",
        language = "c++",
        flags = ["-nostdinc++"],
        source = """
#include <wctype.h>
int main() { return iswblank(L' '); }
""",
    ),
    compile_check(
        name = "HAVE_DECL_STRNLEN",
        language = "c++",
        flags = ["-nostdinc++"],
        source = """
#include <string.h>
int main() { return strnlen("", 1); }
""",
    ),
    compile_check(
        name = "HAVE_OBSOLETE_ISINF",
        language = "c++",
        flags = ["-nostdinc++"],
        source = """
#include <math.h>
#undef isinf
namespace std {
    using ::isinf;
    bool isinf(float);
    bool isinf(long double);
}
using std::isinf;
bool b = isinf(0.0);
int main() { return b; }
""",
    ),
    compile_check(
        name = "HAVE_OBSOLETE_ISNAN",
        language = "c++",
        flags = ["-nostdinc++"],
        source = """
#include <math.h>
#undef isnan
namespace std {
    using ::isnan;
    bool isnan(float);
    bool isnan(long double);
}
using std::isnan;
bool b = isnan(0.0);
int main() { return b; }
""",
    ),
    compile_check(
        name = "HAVE_CC_TLS",
        source = "__thread int a; int b; int main(void) { return a = b; }",
    ),
]

_FILESYSTEM_LINK_CHECKS = [
    _function_link_check("_GLIBCXX_USE_CHMOD", "sys/stat.h", 'int i = chmod("", S_IRUSR)', compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("_GLIBCXX_USE_MKDIR", "sys/stat.h", 'int i = mkdir("", S_IRUSR)', compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("_GLIBCXX_USE_CHDIR", "unistd.h", 'int i = chdir("")', compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("_GLIBCXX_USE_GETCWD", "unistd.h", "char *s = getcwd((char *)0, 1)", compile_flags = _CXX_FILESYSTEM_FLAGS),
    link_check(
        name = "_GLIBCXX_USE_REALPATH",
        compile_flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <limits.h>
#include <stdlib.h>
#include <unistd.h>
int main() {
#if _XOPEN_VERSION < 500
#error _XOPEN_VERSION is too old
#elif _XOPEN_VERSION >= 700 || defined(PATH_MAX)
    char *tmp = realpath((const char *)0, (char *)0);
    return tmp != 0;
#else
#error realpath needs PATH_MAX before XSI 700
#endif
}
""",
    ),
    link_check(
        name = "_GLIBCXX_USE_UTIMENSAT",
        compile_flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <fcntl.h>
#include <sys/stat.h>
int main() {
    timespec ts[2] = {{0, UTIME_OMIT}, {1, 1}};
    int i = utimensat(AT_FDCWD, "path", ts, 0);
    return i;
}
""",
    ),
    link_check(
        name = "_GLIBCXX_USE_UTIME",
        compile_flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <utime.h>
int main() {
    utimbuf t = {1, 1};
    int i = utime("path", &t);
    return i;
}
""",
    ),
    link_check(
        name = "_GLIBCXX_USE_LSTAT",
        compile_flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <sys/stat.h>
int main() {
    struct stat st;
    int i = lstat("path", &st);
    return i;
}
""",
    ),
    link_check(
        name = "_GLIBCXX_USE_ST_MTIM",
        compile_flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <sys/stat.h>
int main() {
    struct stat st;
    return st.st_mtim.tv_nsec;
}
""",
    ),
    _function_link_check("_GLIBCXX_USE_FCHMOD", "sys/stat.h", "fchmod(1, S_IWUSR)", compile_flags = _CXX_FILESYSTEM_FLAGS),
    link_check(
        name = "_GLIBCXX_USE_FCHMODAT",
        compile_flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <fcntl.h>
#include <sys/stat.h>
int main() { fchmodat(AT_FDCWD, "", 0, AT_SYMLINK_NOFOLLOW); return 0; }
""",
    ),
    _function_link_check("HAVE_LINK", "unistd.h", 'link("", "")', compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("HAVE_LSEEK", "unistd.h", "lseek(1, 0, SEEK_SET)", compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("HAVE_READLINK", "unistd.h", 'char buf[32]; readlink("", buf, sizeof(buf))', compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("HAVE_SYMLINK", "unistd.h", 'symlink("", "")', compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("HAVE_TRUNCATE", "unistd.h", 'truncate("", 99)', compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("_GLIBCXX_USE_SENDFILE", "sys/sendfile.h", "sendfile(1, 2, (off_t *)0, sizeof 1)", compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("HAVE_FDOPENDIR", "dirent.h", "DIR *dir = fdopendir(1)", compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("HAVE_DIRFD", "dirent.h", "int fd = dirfd((DIR *)0)", compile_flags = _CXX_FILESYSTEM_FLAGS),
    _function_link_check("HAVE_OPENAT", "fcntl.h", 'int fd = openat(AT_FDCWD, "", 0)', compile_flags = _CXX_FILESYSTEM_FLAGS),
    link_check(
        name = "HAVE_UNLINKAT",
        compile_flags = _CXX_FILESYSTEM_FLAGS,
        source = """
#include <fcntl.h>
#include <unistd.h>
int main() { unlinkat(AT_FDCWD, "", AT_REMOVEDIR); return 0; }
""",
    ),
]

_MATH_FUNCTIONS = [
    ("HAVE_ACOSF", "acosf(0.0f)"),
    ("HAVE_ACOSL", "acosl(0.0L)"),
    ("HAVE_ASINF", "asinf(0.0f)"),
    ("HAVE_ASINL", "asinl(0.0L)"),
    ("HAVE_ATAN2F", "atan2f(0.0f, 1.0f)"),
    ("HAVE_ATAN2L", "atan2l(0.0L, 1.0L)"),
    ("HAVE_ATANF", "atanf(0.0f)"),
    ("HAVE_ATANL", "atanl(0.0L)"),
    ("HAVE_CEILF", "ceilf(0.0f)"),
    ("HAVE_CEILL", "ceill(0.0L)"),
    ("HAVE_COSF", "cosf(0.0f)"),
    ("HAVE_COSHF", "coshf(0.0f)"),
    ("HAVE_COSHL", "coshl(0.0L)"),
    ("HAVE_COSL", "cosl(0.0L)"),
    ("HAVE_EXPF", "expf(0.0f)"),
    ("HAVE_EXPL", "expl(0.0L)"),
    ("HAVE_FABSF", "fabsf(0.0f)"),
    ("HAVE_FABSL", "fabsl(0.0L)"),
    ("HAVE_FINITE", "finite(0.0)"),
    ("HAVE_FINITEF", "finitef(0.0f)"),
    ("HAVE_FINITEL", "finitel(0.0L)"),
    ("HAVE_FLOORF", "floorf(0.0f)"),
    ("HAVE_FLOORL", "floorl(0.0L)"),
    ("HAVE_FMODF", "fmodf(1.0f, 1.0f)"),
    ("HAVE_FMODL", "fmodl(1.0L, 1.0L)"),
    ("HAVE_FREXPF", "frexpf(1.0f, &i)"),
    ("HAVE_FREXPL", "frexpl(1.0L, &i)"),
    ("HAVE_HYPOT", "hypot(1.0, 1.0)"),
    ("HAVE_HYPOTF", "hypotf(1.0f, 1.0f)"),
    ("HAVE_HYPOTL", "hypotl(1.0L, 1.0L)"),
    ("HAVE_ISINF", "isinf(0.0)"),
    ("HAVE_ISINFF", "isinff(0.0f)"),
    ("HAVE_ISINFL", "isinfl(0.0L)"),
    ("HAVE_ISNAN", "isnan(0.0)"),
    ("HAVE_ISNANF", "isnanf(0.0f)"),
    ("HAVE_ISNANL", "isnanl(0.0L)"),
    ("HAVE_LDEXPF", "ldexpf(1.0f, 1)"),
    ("HAVE_LDEXPL", "ldexpl(1.0L, 1)"),
    ("HAVE_LOG10F", "log10f(1.0f)"),
    ("HAVE_LOG10L", "log10l(1.0L)"),
    ("HAVE_LOGF", "logf(1.0f)"),
    ("HAVE_LOGL", "logl(1.0L)"),
    ("HAVE_MODF", "modf(1.0, &d)"),
    ("HAVE_MODFF", "modff(1.0f, &f)"),
    ("HAVE_MODFL", "modfl(1.0L, &ld)"),
    ("HAVE_POWF", "powf(1.0f, 1.0f)"),
    ("HAVE_POWL", "powl(1.0L, 1.0L)"),
    ("HAVE_SINCOS", "sincos(1.0, &sd, &cd)"),
    ("HAVE_SINCOSF", "sincosf(1.0f, &sf, &cf)"),
    ("HAVE_SINCOSL", "sincosl(1.0L, &sld, &cld)"),
    ("HAVE_SINF", "sinf(0.0f)"),
    ("HAVE_SINHF", "sinhf(0.0f)"),
    ("HAVE_SINHL", "sinhl(0.0L)"),
    ("HAVE_SINL", "sinl(0.0L)"),
    ("HAVE_SQRTF", "sqrtf(1.0f)"),
    ("HAVE_SQRTL", "sqrtl(1.0L)"),
    ("HAVE_TANF", "tanf(0.0f)"),
    ("HAVE_TANHF", "tanhf(0.0f)"),
    ("HAVE_TANHL", "tanhl(0.0L)"),
    ("HAVE_TANL", "tanl(0.0L)"),
]

_MATH_SOURCE_PREFIX = """
#define _GNU_SOURCE 1
#include <math.h>
int i;
double d;
float f;
long double ld;
double sd;
double cd;
float sf;
float cf;
long double sld;
long double cld;
"""

_MATH_LINK_CHECKS = [
    link_check(
        name = name,
        link_flags = _MATH_LINK_FLAGS,
        source = _MATH_SOURCE_PREFIX + """
int main() {{
    {expression};
    return 0;
}}
""".format(expression = expression),
    )
    for name, expression in _MATH_FUNCTIONS
]

_STDLIB_LINK_CHECKS = [
    _function_link_check("HAVE_ALIGNED_ALLOC", "stdlib.h", "void *p = aligned_alloc(16, 16)"),
    _function_link_check("HAVE_POSIX_MEMALIGN", "stdlib.h", "void *p = 0; posix_memalign(&p, 16, 16)"),
    _function_link_check("HAVE_MEMALIGN", "malloc.h", "void *p = memalign(16, 16)"),
    _function_link_check("HAVE__ALIGNED_MALLOC", "malloc.h", "void *p = _aligned_malloc(16, 16)"),
    _function_link_check("HAVE_AT_QUICK_EXIT", "stdlib.h", "at_quick_exit((void (*)(void))0)"),
    _function_link_check("HAVE_QUICK_EXIT", "stdlib.h", "quick_exit(0)"),
    _function_link_check("HAVE_SECURE_GETENV", "stdlib.h", 'char *p = secure_getenv("PATH")'),
    _function_link_check("HAVE_STRTOF", "stdlib.h", 'float f = strtof("1", (char **)0)'),
    _function_link_check("HAVE_STRTOLD", "stdlib.h", 'long double ld = strtold("1", (char **)0)'),
    _function_link_check("HAVE_TIMESPEC_GET", "time.h", "struct timespec ts; timespec_get(&ts, TIME_UTC)"),
]

_IO_AND_LOCALE_LINK_CHECKS = [
    _function_link_check("HAVE_STRERROR_L", "string.h", "char *s = strerror_l(0, (locale_t)0)"),
    _function_link_check("HAVE_STRERROR_R", "string.h", "char buf[64]; strerror_r(0, buf, sizeof(buf))"),
    _function_link_check("HAVE_STRXFRM_L", "string.h", 'char dst[64]; strxfrm_l(dst, "", sizeof(dst), (locale_t)0)'),
    _function_link_check("HAVE_USELOCALE", "locale.h", "locale_t loc = uselocale((locale_t)0)"),
    link_check(
        name = "HAVE_VFWSCANF",
        source = """
#include <stdarg.h>
#include <stdio.h>
#include <wchar.h>
int test(const wchar_t *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int result = vfwscanf((FILE *)0, fmt, ap);
    va_end(ap);
    return result;
}
int main() { return 0; }
""",
    ),
    link_check(
        name = "HAVE_VSWSCANF",
        source = """
#include <stdarg.h>
#include <wchar.h>
int test(const wchar_t *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int result = vswscanf(L"", fmt, ap);
    va_end(ap);
    return result;
}
int main() { return 0; }
""",
    ),
    link_check(
        name = "HAVE_VWSCANF",
        source = """
#include <stdarg.h>
#include <wchar.h>
int test(const wchar_t *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int result = vwscanf(fmt, ap);
    va_end(ap);
    return result;
}
int main() { return 0; }
""",
    ),
    _function_link_check("HAVE_WCSTOF", "wchar.h", "float f = wcstof(L\"1\", (wchar_t **)0)"),
    _function_link_check("HAVE_FWRITE_UNLOCKED", "stdio.h", 'fwrite_unlocked("", 1, 1, stdout)'),
    _function_link_check("HAVE_GETS", "stdio.h", "char buf[8]; gets(buf)"),
    _function_link_check("HAVE__WFOPEN", "wchar.h", 'FILE *f = _wfopen(L"", L"r")'),
]

_THREAD_AND_OS_LINK_CHECKS = [
    link_check(
        name = "HAVE___CXA_THREAD_ATEXIT",
        source = """
extern "C" int __cxa_thread_atexit(void (*)(void *), void *, void *);
int main() { return __cxa_thread_atexit((void (*)(void *))0, (void *)0, (void *)0); }
""",
    ),
    link_check(
        name = "HAVE___CXA_THREAD_ATEXIT_IMPL",
        source = """
extern "C" int __cxa_thread_atexit_impl(void (*)(void *), void *, void *);
int main() { return __cxa_thread_atexit_impl((void (*)(void *))0, (void *)0, (void *)0); }
""",
    ),
    _function_link_check("HAVE_ARC4RANDOM", "stdlib.h", "unsigned x = arc4random()"),
    _function_link_check("HAVE_GETENTROPY", "unistd.h", "char buf[8]; getentropy(buf, sizeof(buf))"),
    _function_link_check("HAVE_SOCKATMARK", "sys/socket.h", "int i = sockatmark(0)"),
    _function_link_check("HAVE_SLEEP", "unistd.h", "sleep(0)"),
    _function_link_check("HAVE_USLEEP", "unistd.h", "usleep(0)"),
    _function_link_check("HAVE_WRITEV", "sys/uio.h", "struct iovec iov; writev(1, &iov, 1)"),
    _function_link_check("HAVE_GETIPINFO", "netdb.h", "getaddrinfo((const char *)0, (const char *)0, (const struct addrinfo *)0, (struct addrinfo **)0)"),
    link_check(
        name = "HAVE_TLS",
        language = "c",
        source = "__thread int a; int b; int main(void) { return a = b; }",
    ),
]

LINK_CHECKS = _FILESYSTEM_LINK_CHECKS + _MATH_LINK_CHECKS + _STDLIB_LINK_CHECKS + _IO_AND_LOCALE_LINK_CHECKS + _THREAD_AND_OS_LINK_CHECKS

POLICY_DEFINES = [
    policy_define("_GLIBCXX_HOSTED", "__STDC_HOSTED__"),
    policy_define("_GLIBCXX_USE_LONG_LONG"),
    policy_define("_GLIBCXX_USE_C99"),
    policy_define("_GLIBCXX_USE_DUAL_ABI"),
    policy_define("_GLIBCXX_USE_CXX11_ABI"),
    policy_define("_GLIBCXX_ATOMIC_WORD_BUILTINS"),
    policy_define("_GLIBCXX_FULLY_DYNAMIC_STRING", "0"),
    policy_define("_GLIBCXX_STDIO_EOF", "-1"),
    policy_define("_GLIBCXX_STDIO_SEEK_CUR", "1"),
    policy_define("_GLIBCXX_STDIO_SEEK_END", "2"),
    policy_undef("_GLIBCXX_CONCEPT_CHECKS"),
    policy_undef("_GLIBCXX_STATIC_TZDATA"),
]
