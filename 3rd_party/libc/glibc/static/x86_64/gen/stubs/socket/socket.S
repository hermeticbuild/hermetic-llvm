#define SYSCALL_NAME socket
#define SYSCALL_NARGS 3
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __socket
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__socket, socket)
hidden_weak (socket)
