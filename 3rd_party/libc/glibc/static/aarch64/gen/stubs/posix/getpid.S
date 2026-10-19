#define SYSCALL_NAME getpid
#define SYSCALL_NARGS 0
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __getpid
#define SYSCALL_NOERRNO 1
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__getpid, getpid)
hidden_weak (getpid)
