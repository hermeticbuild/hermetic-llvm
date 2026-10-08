#define SYSCALL_NAME pkey_alloc
#define SYSCALL_NARGS 2
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __pkey_alloc
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__pkey_alloc, pkey_alloc)
hidden_weak (pkey_alloc)
