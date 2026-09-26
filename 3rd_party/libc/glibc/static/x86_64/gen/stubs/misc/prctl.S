#define SYSCALL_NAME prctl
#define SYSCALL_NARGS 5
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __prctl
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__prctl, prctl)
hidden_weak (prctl)
weak_alias (__prctl, __prctl_time64)
hidden_weak (__prctl_time64)
