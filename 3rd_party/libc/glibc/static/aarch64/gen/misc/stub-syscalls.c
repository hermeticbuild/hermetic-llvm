#define __compat_bdflush RENAMED___compat_bdflush
#define bdflush RENAMED_bdflush
#define __compat_create_module RENAMED___compat_create_module
#define create_module RENAMED_create_module
#define __compat_get_kernel_syms RENAMED___compat_get_kernel_syms
#define get_kernel_syms RENAMED_get_kernel_syms
#define __compat_query_module RENAMED___compat_query_module
#define query_module RENAMED_query_module
#define __compat_uselib RENAMED___compat_uselib
#define uselib RENAMED_uselib
#include <errno.h>
#include <shlib-compat.h>
#undef __compat_bdflush
#undef bdflush
#undef __compat_create_module
#undef create_module
#undef __compat_get_kernel_syms
#undef get_kernel_syms
#undef __compat_query_module
#undef query_module
#undef __compat_uselib
#undef uselib
long int _no_syscall (void)
{ __set_errno (ENOSYS); return -1L; }
weak_alias (_no_syscall, __compat_bdflush)
stub_warning (__compat_bdflush)
weak_alias (_no_syscall, __GI___compat_bdflush)
#if SHLIB_COMPAT (libc, GLIBC_2_0, GLIBC_2_23)
strong_alias (_no_syscall, __bdflush_GLIBC_2_0)
compat_symbol (libc, __bdflush_GLIBC_2_0, bdflush, GLIBC_2_0);
#endif
weak_alias (_no_syscall, __compat_create_module)
stub_warning (__compat_create_module)
weak_alias (_no_syscall, __GI___compat_create_module)
#if SHLIB_COMPAT (libc, GLIBC_2_0, GLIBC_2_23)
strong_alias (_no_syscall, __create_module_GLIBC_2_0)
compat_symbol (libc, __create_module_GLIBC_2_0, create_module, GLIBC_2_0);
#endif
weak_alias (_no_syscall, __compat_get_kernel_syms)
stub_warning (__compat_get_kernel_syms)
weak_alias (_no_syscall, __GI___compat_get_kernel_syms)
#if SHLIB_COMPAT (libc, GLIBC_2_0, GLIBC_2_23)
strong_alias (_no_syscall, __get_kernel_syms_GLIBC_2_0)
compat_symbol (libc, __get_kernel_syms_GLIBC_2_0, get_kernel_syms, GLIBC_2_0);
#endif
weak_alias (_no_syscall, __compat_query_module)
stub_warning (__compat_query_module)
weak_alias (_no_syscall, __GI___compat_query_module)
#if SHLIB_COMPAT (libc, GLIBC_2_0, GLIBC_2_23)
strong_alias (_no_syscall, __query_module_GLIBC_2_0)
compat_symbol (libc, __query_module_GLIBC_2_0, query_module, GLIBC_2_0);
#endif
weak_alias (_no_syscall, __compat_uselib)
stub_warning (__compat_uselib)
weak_alias (_no_syscall, __GI___compat_uselib)
#if SHLIB_COMPAT (libc, GLIBC_2_0, GLIBC_2_23)
strong_alias (_no_syscall, __uselib_GLIBC_2_0)
compat_symbol (libc, __uselib_GLIBC_2_0, uselib, GLIBC_2_0);
#endif
