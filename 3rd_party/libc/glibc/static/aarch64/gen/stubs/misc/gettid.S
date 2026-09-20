#define SYSCALL_NAME gettid
#define SYSCALL_NARGS 0
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __gettid
#define SYSCALL_NOERRNO 1
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__gettid, gettid)
hidden_weak (gettid)
