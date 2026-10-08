#define SYSCALL_NAME setsid
#define SYSCALL_NARGS 0
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __setsid
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__setsid, setsid)
hidden_weak (setsid)
