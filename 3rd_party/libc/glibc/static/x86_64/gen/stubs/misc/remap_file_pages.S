#define SYSCALL_NAME remap_file_pages
#define SYSCALL_NARGS 5
#define SYSCALL_ULONG_ARG_1 2
#define SYSCALL_ULONG_ARG_2 4
#define SYSCALL_SYMBOL __remap_file_pages
#define SYSCALL_NOERRNO 0
#define SYSCALL_ERRVAL 0
#include <syscall-template.S>
weak_alias (__remap_file_pages, remap_file_pages)
hidden_weak (remap_file_pages)
