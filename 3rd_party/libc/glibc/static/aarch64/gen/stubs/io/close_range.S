#define SYSCALL_NAME close_range
#define SYSCALL_NARGS 3
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __close_range
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__close_range, close_range)
hidden_weak (close_range)
