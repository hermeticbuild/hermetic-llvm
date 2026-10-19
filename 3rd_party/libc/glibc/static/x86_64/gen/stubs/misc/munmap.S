#define SYSCALL_NAME munmap
#define SYSCALL_NARGS 2
#define SYSCALL_ULONG_ARG_1 2
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __munmap
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__munmap, munmap)
hidden_weak (munmap)
