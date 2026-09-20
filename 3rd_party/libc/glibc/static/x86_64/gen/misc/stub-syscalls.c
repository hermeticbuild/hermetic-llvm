#define __compat_bdflush RENAMED___compat_bdflush
#define bdflush RENAMED_bdflush
#include <errno.h>
#include <shlib-compat.h>
#undef __compat_bdflush
#undef bdflush
long int _no_syscall (void)
{ __set_errno (ENOSYS); return -1L; }
weak_alias (_no_syscall, __compat_bdflush)
stub_warning (__compat_bdflush)
weak_alias (_no_syscall, __GI___compat_bdflush)
#if SHLIB_COMPAT (libc, GLIBC_2_0, GLIBC_2_23)
strong_alias (_no_syscall, __bdflush_GLIBC_2_0)
compat_symbol (libc, __bdflush_GLIBC_2_0, bdflush, GLIBC_2_0);
#endif
