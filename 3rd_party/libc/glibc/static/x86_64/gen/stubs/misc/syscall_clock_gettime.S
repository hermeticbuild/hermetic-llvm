#define SYSCALL_NAME clock_gettime
#define SYSCALL_NARGS 2
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __syscall_clock_gettime
#define SYSCALL_NOERRNO 1
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
