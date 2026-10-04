#define SYSCALL_NAME modify_ldt
#define SYSCALL_NARGS 3
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __modify_ldt
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__modify_ldt, modify_ldt)
hidden_weak (modify_ldt)
