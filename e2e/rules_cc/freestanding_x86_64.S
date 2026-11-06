// Exit successfully using the x86-64 Linux syscall ABI.
.text
.globl _start
_start:
    xorl %edi, %edi
    movl $60, %eax
    syscall
.section .note.GNU-stack,"",@progbits
