#define SYSCALL_NAME chown
#define SYSCALL_NARGS 3
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __libc_chown
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__libc_chown, __chown)
hidden_weak (__chown)
weak_alias (__libc_chown, chown)
hidden_weak (chown)
