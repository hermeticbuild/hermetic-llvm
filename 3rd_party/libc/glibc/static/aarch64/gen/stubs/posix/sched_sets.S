#define SYSCALL_NAME sched_setscheduler
#define SYSCALL_NARGS 3
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __sched_setscheduler
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__sched_setscheduler, sched_setscheduler)
hidden_weak (sched_setscheduler)
