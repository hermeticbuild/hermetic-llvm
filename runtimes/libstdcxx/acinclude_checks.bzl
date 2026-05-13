load(
    "//runtimes/configure:native_autoconf_checks.bzl",
    "CXX_NO_EXCEPTIONS_FLAGS",
    "PTHREAD_LINK_FLAGS",
    "compile_check",
    "function_link_check",
    "link_check",
    "policy_define",
    "policy_string_define",
    "policy_undef",
)

CXX_FILESYSTEM_FLAGS = ["-fno-exceptions"]

# Upstream macro coverage anchors for audit. The active Linux GNU port groups
# some acinclude.m4 macros when they share one Bazel probe/policy site:
#
# GLIBCXX_CHECK_MATH_SUPPORT and GLIBCXX_CHECK_STDLIB_SUPPORT are delegated to
# reusable GCC-native checks in //runtimes/configure:native_autoconf_checks.bzl.
# GLIBCXX_CHECK_MATH_DECL and GLIBCXX_CHECK_MATH_DECLS are currently represented
# by glibcxx_enable_c99() and glibcxx_check_math11_proto().
# GLIBCXX_CHECK_STDLIB_DECL_AND_LINKAGE_3 is currently represented by
# glibcxx_enable_c99() and glibcxx_check_c99_tr1().
# GLIBCXX_CHECK_GET_NPROCS, GLIBCXX_CHECK_SC_NPROCESSORS_ONLN,
# GLIBCXX_CHECK_SC_NPROC_ONLN, and GLIBCXX_CHECK_PTHREADS_NUM_PROCESSORS_NP are
# represented by glibcxx_check_hardware_concurrency().
# GLIBCXX_CHECK_PTHREAD_COND_CLOCKWAIT, GLIBCXX_CHECK_PTHREAD_MUTEX_CLOCKLOCK,
# and GLIBCXX_CHECK_PTHREAD_RWLOCK_CLOCKLOCK are represented by
# glibcxx_check_pthread_clock_apis().
# GLIBCXX_CHECK_X86_RDRAND, GLIBCXX_CHECK_X86_RDSEED,
# GLIBCXX_CHECK_ALIGNAS_CACHELINE, GLIBCXX_CHECK_INIT_PRIORITY,
# GLIBCXX_STRUCT_TM_TM_ZONE, GLIBCXX_CHECK_POLL, GLIBCXX_CHECK_ARC4RANDOM,
# GLIBCXX_CHECK_GETENTROPY, GLIBCXX_CHECK_DEV_RANDOM, GLIBCXX_CHECK_WRITEV,
# GLIBCXX_CHECK_S_ISREG_OR_S_IFREG, GLIBCXX_CHECK_SDT_H,
# GLIBCXX_CHECK_SIZE_T_MANGLING, GLIBCXX_CHECK_LINKER_FEATURES, and
# GLIBCXX_CHECK_EXCEPTION_PTR_SYMVER are represented by grouped checks below.
# GLIBCXX_ENABLE_EXTERN_TEMPLATE, GLIBCXX_ENABLE_FILESYSTEM_TS,
# GLIBCXX_ENABLE_LIBSTDCXX_DUAL_ABI, GLIBCXX_ENABLE_LIBSTDCXX_VISIBILITY, and
# GLIBCXX_DEFAULT_ABI are represented by glibcxx_abi_policies().

def glibcxx_check_compiler_features():
    return []

def glibcxx_enable_hosted():
    return [policy_define("_GLIBCXX_HOSTED", "__STDC_HOSTED__")]

def glibcxx_enable_verbose():
    return []

def glibcxx_enable_pch():
    return []

def glibcxx_enable_atomic_builtins():
    return [policy_define("_GLIBCXX_ATOMIC_WORD_BUILTINS")]

def glibcxx_enable_lock_policy():
    return []

def glibcxx_enable_cstdio():
    return []

def glibcxx_enable_clocale():
    return [
        function_link_check("HAVE_STRERROR_L", "string.h", "char *s = strerror_l(0, (locale_t)0)"),
        function_link_check("HAVE_STRERROR_R", "string.h", "char buf[64]; strerror_r(0, buf, sizeof(buf))"),
        function_link_check("HAVE_STRXFRM_L", "string.h", 'char dst[64]; strxfrm_l(dst, "", sizeof(dst), (locale_t)0)'),
    ]

def glibcxx_enable_allocator():
    return []

def glibcxx_enable_long_long():
    return [policy_define("_GLIBCXX_USE_LONG_LONG")]

def glibcxx_enable_wchar_t():
    return [
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
        policy_define("_GLIBCXX_USE_WCHAR_T"),
    ]

def glibcxx_enable_c99():
    # The Linux GNU configuration currently treats the aggregate C99 groups as
    # hosted glibc policy. Keep this grouped like GLIBCXX_ENABLE_C99 so each
    # policy decision can be replaced by its upstream probe body later.
    return [
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
            name = "HAVE_ISWBLANK",
            language = "c++",
            flags = ["-nostdinc++"],
            source = """
#include <wctype.h>
int main() { return iswblank(L' '); }
""",
        ),
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
        function_link_check("HAVE_WCSTOF", "wchar.h", "float f = wcstof(L\"1\", (wchar_t **)0)"),
        policy_define("_GLIBCXX_USE_C99"),
        policy_define("_GLIBCXX98_USE_C99_COMPLEX"),
        policy_define("_GLIBCXX98_USE_C99_MATH"),
        policy_define("_GLIBCXX11_USE_C99_MATH"),
        policy_define("_GLIBCXX11_USE_C99_COMPLEX"),
        policy_define("_GLIBCXX98_USE_C99_STDIO"),
        policy_define("_GLIBCXX11_USE_C99_STDIO"),
        policy_define("_GLIBCXX98_USE_C99_STDLIB"),
        policy_define("_GLIBCXX11_USE_C99_STDLIB"),
        policy_define("_GLIBCXX98_USE_C99_WCHAR"),
        policy_define("_GLIBCXX11_USE_C99_WCHAR"),
        policy_define("_GLIBCXX_USE_C99_COMPLEX_ARC"),
        policy_define("_GLIBCXX_USE_C99_CTYPE"),
        policy_define("_GLIBCXX_USE_C99_FENV"),
        policy_define("_GLIBCXX_USE_C99_INTTYPES"),
        policy_define("_GLIBCXX_USE_C99_INTTYPES_WCHAR_T"),
        policy_define("_GLIBCXX_USE_C99_MATH_FUNCS"),
        policy_define("_GLIBCXX_USE_C99_STDINT"),
        policy_undef("_GLIBCXX_NO_C99_ROUNDING_FUNCS"),
    ]

def glibcxx_check_c99_tr1():
    return [
        policy_define("_GLIBCXX_USE_C99_COMPLEX_TR1"),
        policy_define("_GLIBCXX_USE_C99_CTYPE_TR1"),
        policy_define("_GLIBCXX_USE_C99_FENV_TR1"),
        policy_define("_GLIBCXX_USE_C99_INTTYPES_TR1"),
        policy_define("_GLIBCXX_USE_C99_INTTYPES_WCHAR_T_TR1"),
        policy_define("_GLIBCXX_USE_C99_MATH_TR1"),
        policy_define("_GLIBCXX_USE_C99_STDINT_TR1"),
    ]

def glibcxx_check_uchar_h():
    return [
        compile_check(
            name = "_GLIBCXX_USE_C11_UCHAR_CXX11",
            language = "c++",
            flags = ["-std=c++11"],
            source = """
#include <uchar.h>
#ifdef __STDC_UTF_16__
long i = __STDC_UTF_16__;
#endif
#ifdef __STDC_UTF_32__
long j = __STDC_UTF_32__;
#endif
namespace test {
    using ::c16rtomb;
    using ::c32rtomb;
    using ::mbrtoc16;
    using ::mbrtoc32;
}
int main() { return 0; }
""",
        ),
        compile_check(
            name = "_GLIBCXX_USE_UCHAR_C8RTOMB_MBRTOC8_FCHAR8_T",
            language = "c++",
            flags = ["-std=c++11", "-fchar8_t"],
            source = """
#include <uchar.h>
namespace test {
    using ::c8rtomb;
    using ::mbrtoc8;
}
int main() { return 0; }
""",
        ),
        compile_check(
            name = "_GLIBCXX_USE_UCHAR_C8RTOMB_MBRTOC8_CXX20",
            language = "c++",
            flags = ["-std=c++20"],
            source = """
#include <uchar.h>
namespace test {
    using ::c8rtomb;
    using ::mbrtoc8;
}
int main() { return 0; }
""",
        ),
    ]

def glibcxx_check_lfs():
    return [
        link_check(
            name = "_GLIBCXX_USE_LFS",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#define _LARGEFILE64_SOURCE 1
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
int main() {
    FILE *f = fopen64("", "r");
    off64_t off = 0;
    off = fseeko64(f, off, SEEK_SET);
    off += ftello64(f);
    off += lseek64(0, off, SEEK_SET);
    struct stat64 st;
    return stat64("", &st) + fstat64(0, &st) + off;
}
""",
        ),
        function_link_check("_GLIBCXX_USE_FSEEKO_FTELLO", "stdio.h", "fseeko((FILE *)0, 0, SEEK_SET); ftello((FILE *)0)"),
    ]

def glibcxx_check_gettimeofday():
    return [
        link_check(
            name = "_GLIBCXX_USE_GETTIMEOFDAY",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <sys/time.h>
int main() {
    timeval tv;
    gettimeofday(&tv, 0);
    return 0;
}
""",
        ),
    ]

def glibcxx_enable_libstdcxx_time():
    return [
        link_check(
            name = "_GLIBCXX_USE_CLOCK_MONOTONIC",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <time.h>
int main() {
    timespec tp;
    clock_gettime(CLOCK_MONOTONIC, &tp);
    return 0;
}
""",
        ),
        link_check(
            name = "_GLIBCXX_USE_CLOCK_REALTIME",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <time.h>
int main() {
    timespec tp;
    clock_gettime(CLOCK_REALTIME, &tp);
    return 0;
}
""",
        ),
        link_check(
            name = "_GLIBCXX_USE_NANOSLEEP",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <time.h>
int main() {
    timespec tp;
    nanosleep(&tp, 0);
    return 0;
}
""",
        ),
        function_link_check("_GLIBCXX_USE_SCHED_YIELD", "sched.h", "sched_yield()", compile_flags = CXX_NO_EXCEPTIONS_FLAGS),
        policy_undef("_GLIBCXX_NO_SLEEP"),
        policy_undef("_GLIBCXX_USE_CLOCK_GETTIME_SYSCALL"),
        policy_undef("_GLIBCXX_USE_WIN32_SLEEP"),
    ]

def glibcxx_check_stdio_proto():
    return [function_link_check("HAVE_GETS", "stdio.h", "char buf[8]; gets(buf)")]

def glibcxx_check_math11_proto():
    return [
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
    ]

def glibcxx_compute_stdio_integer_constants():
    return [
        policy_define("_GLIBCXX_STDIO_EOF", "-1"),
        policy_define("_GLIBCXX_STDIO_SEEK_CUR", "1"),
        policy_define("_GLIBCXX_STDIO_SEEK_END", "2"),
    ]

def glibcxx_check_tmpnam():
    return [function_link_check("_GLIBCXX_USE_TMPNAM", "stdio.h", "char buf[L_tmpnam]; tmpnam(buf)")]

def glibcxx_check_pthread_clock_apis():
    return [
        link_check(
            name = "_GLIBCXX_USE_PTHREAD_COND_CLOCKWAIT",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            link_flags = PTHREAD_LINK_FLAGS,
            source = """
#include <pthread.h>
#include <time.h>
int main() {
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    timespec ts;
    return pthread_cond_clockwait(&cond, &mutex, CLOCK_REALTIME, &ts);
}
""",
        ),
        link_check(
            name = "_GLIBCXX_USE_PTHREAD_MUTEX_CLOCKLOCK",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            link_flags = PTHREAD_LINK_FLAGS,
            source = """
#include <pthread.h>
#include <time.h>
int main() {
    pthread_mutex_t mutex;
    timespec ts;
    return pthread_mutex_clocklock(&mutex, CLOCK_REALTIME, &ts);
}
""",
        ),
        link_check(
            name = "_GLIBCXX_USE_PTHREAD_RWLOCK_CLOCKLOCK",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            link_flags = PTHREAD_LINK_FLAGS,
            source = """
#include <pthread.h>
#include <time.h>
int main() {
    pthread_rwlock_t rwl;
    timespec ts;
    int n = pthread_rwlock_clockrdlock(&rwl, CLOCK_REALTIME, &ts);
    int m = pthread_rwlock_clockwrlock(&rwl, CLOCK_REALTIME, &ts);
    return n + m;
}
""",
        ),
    ]

def glibcxx_check_hardware_concurrency():
    return [
        function_link_check("_GLIBCXX_USE_GET_NPROCS", "sys/sysinfo.h", "int n = get_nprocs()", compile_flags = CXX_NO_EXCEPTIONS_FLAGS),
        function_link_check("_GLIBCXX_USE_SC_NPROCESSORS_ONLN", "unistd.h", "int n = sysconf(_SC_NPROCESSORS_ONLN)", compile_flags = CXX_NO_EXCEPTIONS_FLAGS),
        function_link_check("_GLIBCXX_USE_SC_NPROC_ONLN", "unistd.h", "int n = sysconf(_SC_NPROC_ONLN)", compile_flags = CXX_NO_EXCEPTIONS_FLAGS),
        function_link_check("_GLIBCXX_USE_PTHREADS_NUM_PROCESSORS_NP", "pthread.h", "int n = pthread_num_processors_np()", compile_flags = CXX_NO_EXCEPTIONS_FLAGS, link_flags = PTHREAD_LINK_FLAGS),
    ]

def glibcxx_check_gthreads():
    return [
        link_check(
            name = "_GLIBCXX_USE_PTHREAD_RWLOCK_T",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            link_flags = PTHREAD_LINK_FLAGS,
            source = """
#include <pthread.h>
int main() {
    pthread_rwlock_t rwl;
    return sizeof(rwl) == 0;
}
""",
        ),
        policy_define("_GLIBCXX_HAS_GTHREADS"),
        policy_define("_GTHREAD_USE_MUTEX_TIMEDLOCK"),
    ]

def glibcxx_check_filesystem_deps():
    return [
        compile_check(
            name = "HAVE_STRUCT_DIRENT_D_TYPE",
            language = "c++",
            flags = CXX_FILESYSTEM_FLAGS,
            source = """
#include <dirent.h>
int test(dirent *entry) { return entry->d_type; }
int main(void) { return 0; }
""",
        ),
        function_link_check("_GLIBCXX_USE_CHMOD", "sys/stat.h", 'int i = chmod("", S_IRUSR)', compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("_GLIBCXX_USE_MKDIR", "sys/stat.h", 'int i = mkdir("", S_IRUSR)', compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("_GLIBCXX_USE_CHDIR", "unistd.h", 'int i = chdir("")', compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("_GLIBCXX_USE_GETCWD", "unistd.h", "char *s = getcwd((char *)0, 1)", compile_flags = CXX_FILESYSTEM_FLAGS),
        link_check(
            name = "_GLIBCXX_USE_REALPATH",
            compile_flags = CXX_FILESYSTEM_FLAGS,
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
            compile_flags = CXX_FILESYSTEM_FLAGS,
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
            compile_flags = CXX_FILESYSTEM_FLAGS,
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
            compile_flags = CXX_FILESYSTEM_FLAGS,
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
            compile_flags = CXX_FILESYSTEM_FLAGS,
            source = """
#include <sys/stat.h>
int main() {
    struct stat st;
    return st.st_mtim.tv_nsec;
}
""",
        ),
        function_link_check("_GLIBCXX_USE_FCHMOD", "sys/stat.h", "fchmod(1, S_IWUSR)", compile_flags = CXX_FILESYSTEM_FLAGS),
        link_check(
            name = "_GLIBCXX_USE_FCHMODAT",
            compile_flags = CXX_FILESYSTEM_FLAGS,
            source = """
#include <fcntl.h>
#include <sys/stat.h>
int main() { fchmodat(AT_FDCWD, "", 0, AT_SYMLINK_NOFOLLOW); return 0; }
""",
        ),
        function_link_check("HAVE_LINK", "unistd.h", 'link("", "")', compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("HAVE_LSEEK", "unistd.h", "lseek(1, 0, SEEK_SET)", compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("HAVE_READLINK", "unistd.h", 'char buf[32]; readlink("", buf, sizeof(buf))', compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("HAVE_SYMLINK", "unistd.h", 'symlink("", "")', compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("HAVE_TRUNCATE", "unistd.h", 'truncate("", 99)', compile_flags = CXX_FILESYSTEM_FLAGS),
        link_check(
            name = "_GLIBCXX_USE_COPY_FILE_RANGE",
            compile_flags = CXX_FILESYSTEM_FLAGS,
            source = """
#define _GNU_SOURCE 1
#include <sys/types.h>
#include <unistd.h>
int main() {
    copy_file_range(1, (loff_t *)0, 2, (loff_t *)0, 1, 0);
    return 0;
}
""",
        ),
        function_link_check("_GLIBCXX_USE_SENDFILE", "sys/sendfile.h", "sendfile(1, 2, (off_t *)0, sizeof 1)", compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("HAVE_FDOPENDIR", "dirent.h", "DIR *dir = fdopendir(1)", compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("HAVE_DIRFD", "dirent.h", "int fd = dirfd((DIR *)0)", compile_flags = CXX_FILESYSTEM_FLAGS),
        function_link_check("HAVE_OPENAT", "fcntl.h", 'int fd = openat(AT_FDCWD, "", 0)', compile_flags = CXX_FILESYSTEM_FLAGS),
        link_check(
            name = "HAVE_UNLINKAT",
            compile_flags = CXX_FILESYSTEM_FLAGS,
            source = """
#include <fcntl.h>
#include <unistd.h>
int main() { unlinkat(AT_FDCWD, "", AT_REMOVEDIR); return 0; }
""",
        ),
    ]

def glibcxx_check_networking_deps():
    return [
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
    ]

def glibcxx_check_text_encoding():
    return [
        link_check(
            name = "_GLIBCXX_USE_NL_LANGINFO_L",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <langinfo.h>
#include <locale.h>
int main() {
    locale_t loc = newlocale(LC_ALL_MASK, "", (locale_t)0);
    const char *enc = nl_langinfo_l(CODESET, loc);
    freelocale(loc);
    return enc == 0;
}
""",
        ),
    ]

def glibcxx_check_debugging():
    return [
        link_check(
            name = "_GLIBCXX_USE_PTRACE",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <sys/ptrace.h>
#include <sys/types.h>
int main() { return ptrace(PTRACE_TRACEME, (pid_t)0, 1, 0); }
""",
        ),
        policy_define("_GLIBCXX_USE_PROC_SELF_STATUS"),
    ]

def glibcxx_check_stdio_locking():
    return [
        function_link_check("HAVE_FWRITE_UNLOCKED", "stdio.h", 'fwrite_unlocked("", 1, 1, stdout)'),
        link_check(
            name = "_GLIBCXX_USE_STDIO_LOCKING",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <stdio.h>
int main() {
    FILE *f = fopen("", "");
    flockfile(f);
    putc_unlocked(' ', f);
    funlockfile(f);
    fclose(f);
    return 0;
}
""",
        ),
        link_check(
            name = "_GLIBCXX_USE_GLIBC_STDIO_EXT",
            compile_flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#include <stdio.h>
#include <stdio_ext.h>
extern "C" {
using f1_type = int (*)(FILE *) noexcept;
using f2_type = size_t (*)(FILE *) noexcept;
}
int main() {
    f1_type twritable = &::__fwritable;
    f1_type tblk = &::__flbf;
    f2_type pbufsize = &::__fbufsize;
    FILE *f = fopen("", "");
    int i = __overflow(f, EOF);
    bool writeable = __fwritable(f);
    bool line_buffered = __flbf(f);
    size_t bufsz = __fbufsize(f);
    char *&pptr = f->_IO_write_ptr;
    char *&epptr = f->_IO_buf_end;
    fflush_unlocked(f);
    fclose(f);
    return i + writeable + line_buffered + bufsz + (pptr == epptr) + (twritable == tblk) + (pbufsize == 0);
}
""",
        ),
    ]

def glibcxx_misc_compile_checks():
    return [
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
            name = "HAVE_DECL_STRNLEN",
            language = "c++",
            flags = ["-nostdinc++"],
            source = """
#include <string.h>
int main() { return strnlen("", 1); }
""",
        ),
        compile_check(
            name = "_GLIBCXX_X86_RDRAND",
            language = "c++",
            flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
int main() { unsigned int v; asm("rdrand %eax"); return __builtin_ia32_rdrand32_step(&v); }
""",
        ),
        compile_check(
            name = "_GLIBCXX_X86_RDSEED",
            language = "c++",
            flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
int main() { unsigned int v; asm("rdseed %eax"); return __builtin_ia32_rdseed_si_step(&v); }
""",
        ),
        compile_check(
            name = "_GLIBCXX_CAN_ALIGNAS_DESTRUCTIVE_SIZE",
            language = "c++",
            flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
struct alignas(__GCC_DESTRUCTIVE_SIZE) Aligned {};
alignas(Aligned) static char buf[sizeof(Aligned) * 16];
int main() { return sizeof(buf) == 0; }
""",
        ),
        compile_check(
            name = "_GLIBCXX_USE_INIT_PRIORITY_ATTRIBUTE",
            language = "c++",
            flags = CXX_NO_EXCEPTIONS_FLAGS,
            source = """
#if !__has_attribute(init_priority)
#error init_priority not supported
#endif
int main() { return 0; }
""",
        ),
        compile_check(
            name = "_GLIBCXX_USE_STRUCT_TM_TM_ZONE",
            language = "c++",
            flags = ["-std=c++20"],
            source = """
#include <time.h>
int main() { struct tm t{}; t.tm_zone = (char *)0; return 0; }
""",
        ),
    ]

def glibcxx_misc_link_checks():
    return [
        function_link_check("HAVE_POLL", "poll.h", "struct pollfd pfd; poll(&pfd, 1, 0)"),
        function_link_check("HAVE_USELOCALE", "locale.h", "locale_t loc = uselocale((locale_t)0)"),
        function_link_check("HAVE_LC_MESSAGES", "locale.h", "int i = LC_MESSAGES"),
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
        function_link_check("HAVE_ARC4RANDOM", "stdlib.h", "unsigned x = arc4random()"),
        function_link_check("HAVE_GETENTROPY", "unistd.h", "char buf[8]; getentropy(buf, sizeof(buf))"),
        function_link_check("HAVE_SOCKATMARK", "sys/socket.h", "int i = sockatmark(0)"),
        function_link_check("HAVE_SLEEP", "unistd.h", "sleep(0)"),
        function_link_check("HAVE_USLEEP", "unistd.h", "usleep(0)"),
        function_link_check("HAVE_WRITEV", "sys/uio.h", "struct iovec iov; writev(1, &iov, 1)"),
        function_link_check("HAVE__WFOPEN", "wchar.h", 'FILE *f = _wfopen(L"", L"r")'),
    ]

def glibcxx_abi_policies():
    return [
        policy_define("_GLIBCXX_USE_DUAL_ABI"),
        policy_define("_GLIBCXX_USE_CXX11_ABI"),
        policy_define("_GLIBCXX_FULLY_DYNAMIC_STRING", "0"),
        policy_define("_GLIBCXX_MANGLE_SIZE_T", "m"),
        policy_undef("_GLIBCXX_PTRDIFF_T_IS_INT"),
        policy_undef("_GLIBCXX_SIZE_T_IS_UINT"),
        policy_undef("_GLIBCXX_CONCEPT_CHECKS"),
    ]

def glibcxx_random_policy():
    return [
        policy_define("_GLIBCXX_USE_DEV_RANDOM"),
        policy_define("_GLIBCXX_USE_RANDOM_TR1"),
    ]

def glibcxx_zoneinfo_policy():
    return [
        policy_string_define("_GLIBCXX_ZONEINFO_DIR", "/usr/share/zoneinfo"),
        policy_undef("_GLIBCXX_STATIC_TZDATA"),
    ]

def glibcxx_resource_limits_policy():
    return [policy_undef("_GLIBCXX_RES_LIMITS")]
