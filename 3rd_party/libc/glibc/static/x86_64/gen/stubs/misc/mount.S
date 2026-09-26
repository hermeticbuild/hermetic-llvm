#define SYSCALL_NAME mount
#define SYSCALL_NARGS 5
#define SYSCALL_ULONG_ARG_1 4
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __mount
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__mount, mount)
hidden_weak (mount)
