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

def policy_string_define(name, value):
    return struct(
        kind = "string_define",
        name = name,
        value = value,
    )

def header_check(header):
    return compile_check(
        name = "HAVE_" + header.upper().replace("/", "_").replace(".", "_"),
        source = """
#include <{header}>
int main(void) {{ return 0; }}
""".format(header = header),
    )

def ac_check_headers(headers):
    return [header_check(header) for header in headers]

def function_link_check(name, header, expression, language = "c++", compile_flags = [], link_flags = []):
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

CXX_NO_EXCEPTIONS_FLAGS = ["-fno-exceptions"]
MATH_LINK_FLAGS = ["-lm"]
PTHREAD_LINK_FLAGS = ["-lpthread"]

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

def gcc_check_math_support():
    return [
        link_check(
            name = name,
            link_flags = MATH_LINK_FLAGS,
            source = _MATH_SOURCE_PREFIX + """
int main() {{
    {expression};
    return 0;
}}
""".format(expression = expression),
        )
        for name, expression in _MATH_FUNCTIONS
    ]

def gcc_check_stdlib_support():
    return [
        function_link_check("HAVE_ALIGNED_ALLOC", "stdlib.h", "void *p = aligned_alloc(16, 16)"),
        function_link_check("HAVE_POSIX_MEMALIGN", "stdlib.h", "void *p = 0; posix_memalign(&p, 16, 16)"),
        function_link_check("HAVE_MEMALIGN", "malloc.h", "void *p = memalign(16, 16)"),
        function_link_check("HAVE__ALIGNED_MALLOC", "malloc.h", "void *p = _aligned_malloc(16, 16)"),
        function_link_check("HAVE_AT_QUICK_EXIT", "stdlib.h", "at_quick_exit((void (*)(void))0)"),
        function_link_check("HAVE_QUICK_EXIT", "stdlib.h", "quick_exit(0)"),
        function_link_check("HAVE_SECURE_GETENV", "stdlib.h", 'char *p = secure_getenv("PATH")'),
        function_link_check("HAVE_SETENV", "stdlib.h", 'setenv("A", "B", 1)'),
        function_link_check("HAVE_STRTOF", "stdlib.h", 'float f = strtof("1", (char **)0)'),
        function_link_check("HAVE_STRTOLD", "stdlib.h", 'long double ld = strtold("1", (char **)0)'),
        function_link_check("HAVE_TIMESPEC_GET", "time.h", "struct timespec ts; timespec_get(&ts, TIME_UTC)"),
    ]

def gcc_check_tls():
    return [
        compile_check(
            name = "HAVE_CC_TLS",
            source = "__thread int a; int b; int main(void) { return a = b; }",
        ),
        link_check(
            name = "HAVE_TLS",
            language = "c",
            source = "__thread int a; int b; int main(void) { return a = b; }",
        ),
    ]

def gcc_check_unwind_getipinfo():
    # config/unwind_ipinfo.m4 defines this by target policy for GCC's own
    # unwinder on Linux GNU targets. It is about _Unwind_GetIPInfo, not
    # networking APIs.
    return [policy_define("HAVE_GETIPINFO")]

def gcc_linux_futex():
    return [
        link_check(
            name = "HAVE_LINUX_FUTEX",
            source = """
#include <linux/futex.h>
#include <sys/syscall.h>
#include <unistd.h>
int main() { return syscall(SYS_futex, (int *)0, FUTEX_WAKE, 1, 0, 0, 0); }
""",
        ),
    ]

def am_iconv():
    return [
        link_check(
            name = "HAVE_ICONV",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <iconv.h>
int main() {
    iconv_t cd = iconv_open("", "");
    iconv(cd, (char **)0, (size_t *)0, (char **)0, (size_t *)0);
    iconv_close(cd);
    return 0;
}
""",
        ),
    ]
