#define SYSCALL_NAME getppid
#define SYSCALL_NARGS 0
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __getppid
#define SYSCALL_NOERRNO 1
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__getppid, getppid)
hidden_weak (getppid)
