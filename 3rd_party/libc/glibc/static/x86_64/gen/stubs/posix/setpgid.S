#define SYSCALL_NAME setpgid
#define SYSCALL_NARGS 2
#define SYSCALL_ULONG_ARG_1 0
#define SYSCALL_ULONG_ARG_2 0
#define SYSCALL_SYMBOL __setpgid
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__setpgid, setpgid)
hidden_weak (setpgid)
