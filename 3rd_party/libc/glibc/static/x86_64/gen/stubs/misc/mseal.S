#define SYSCALL_NAME mseal
#define SYSCALL_NARGS 3
#define SYSCALL_ULONG_ARG_1 2
#define SYSCALL_ULONG_ARG_2 3
#define SYSCALL_SYMBOL __mseal
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__mseal, mseal)
hidden_weak (mseal)
