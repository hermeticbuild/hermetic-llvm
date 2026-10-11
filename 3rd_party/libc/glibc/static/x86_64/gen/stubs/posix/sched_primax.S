#define SYSCALL_NAME sched_get_priority_max
#define SYSCALL_NARGS 1
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __sched_get_priority_max
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__sched_get_priority_max, sched_get_priority_max)
hidden_weak (sched_get_priority_max)
