#define SYSCALL_NAME chdir
#define SYSCALL_NARGS 1
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __chdir
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__chdir, chdir)
hidden_weak (chdir)
