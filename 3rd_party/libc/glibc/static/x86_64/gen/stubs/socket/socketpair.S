#define SYSCALL_NAME socketpair
#define SYSCALL_NARGS 4
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __socketpair
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__socketpair, socketpair)
hidden_weak (socketpair)
