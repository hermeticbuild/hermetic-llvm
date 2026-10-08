#define SYSCALL_NAME umask
#define SYSCALL_NARGS 1
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __umask
#define SYSCALL_NOERRNO 1
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__umask, umask)
hidden_weak (umask)
