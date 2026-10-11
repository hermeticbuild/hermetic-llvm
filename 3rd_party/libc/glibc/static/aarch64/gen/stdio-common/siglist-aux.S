	.file	"siglist-gen.c"
	.type	.L.str,@object                  // @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"Hangup"
	.size	.L.str, 7

	.type	.L.str.1,@object                // @.str.1
.L.str.1:
	.asciz	"Interrupt"
	.size	.L.str.1, 10

	.type	.L.str.2,@object                // @.str.2
.L.str.2:
	.asciz	"Quit"
	.size	.L.str.2, 5

	.type	.L.str.3,@object                // @.str.3
.L.str.3:
	.asciz	"Illegal instruction"
	.size	.L.str.3, 20

	.type	.L.str.4,@object                // @.str.4
.L.str.4:
	.asciz	"Trace/breakpoint trap"
	.size	.L.str.4, 22

	.type	.L.str.5,@object                // @.str.5
.L.str.5:
	.asciz	"Aborted"
	.size	.L.str.5, 8

	.type	.L.str.6,@object                // @.str.6
.L.str.6:
	.asciz	"Bus error"
	.size	.L.str.6, 10

	.type	.L.str.7,@object                // @.str.7
.L.str.7:
	.asciz	"Floating point exception"
	.size	.L.str.7, 25

	.type	.L.str.8,@object                // @.str.8
.L.str.8:
	.asciz	"Killed"
	.size	.L.str.8, 7

	.type	.L.str.9,@object                // @.str.9
.L.str.9:
	.asciz	"User defined signal 1"
	.size	.L.str.9, 22

	.type	.L.str.10,@object               // @.str.10
.L.str.10:
	.asciz	"Segmentation fault"
	.size	.L.str.10, 19

	.type	.L.str.11,@object               // @.str.11
.L.str.11:
	.asciz	"User defined signal 2"
	.size	.L.str.11, 22

	.type	.L.str.12,@object               // @.str.12
.L.str.12:
	.asciz	"Broken pipe"
	.size	.L.str.12, 12

	.type	.L.str.13,@object               // @.str.13
.L.str.13:
	.asciz	"Alarm clock"
	.size	.L.str.13, 12

	.type	.L.str.14,@object               // @.str.14
.L.str.14:
	.asciz	"Terminated"
	.size	.L.str.14, 11

	.type	.L.str.15,@object               // @.str.15
.L.str.15:
	.asciz	"Stack fault"
	.size	.L.str.15, 12

	.type	.L.str.16,@object               // @.str.16
.L.str.16:
	.asciz	"Child exited"
	.size	.L.str.16, 13

	.type	.L.str.17,@object               // @.str.17
.L.str.17:
	.asciz	"Continued"
	.size	.L.str.17, 10

	.type	.L.str.18,@object               // @.str.18
.L.str.18:
	.asciz	"Stopped (signal)"
	.size	.L.str.18, 17

	.type	.L.str.19,@object               // @.str.19
.L.str.19:
	.asciz	"Stopped"
	.size	.L.str.19, 8

	.type	.L.str.20,@object               // @.str.20
.L.str.20:
	.asciz	"Stopped (tty input)"
	.size	.L.str.20, 20

	.type	.L.str.21,@object               // @.str.21
.L.str.21:
	.asciz	"Stopped (tty output)"
	.size	.L.str.21, 21

	.type	.L.str.22,@object               // @.str.22
.L.str.22:
	.asciz	"Urgent I/O condition"
	.size	.L.str.22, 21

	.type	.L.str.23,@object               // @.str.23
.L.str.23:
	.asciz	"CPU time limit exceeded"
	.size	.L.str.23, 24

	.type	.L.str.24,@object               // @.str.24
.L.str.24:
	.asciz	"File size limit exceeded"
	.size	.L.str.24, 25

	.type	.L.str.25,@object               // @.str.25
.L.str.25:
	.asciz	"Virtual timer expired"
	.size	.L.str.25, 22

	.type	.L.str.26,@object               // @.str.26
.L.str.26:
	.asciz	"Profiling timer expired"
	.size	.L.str.26, 24

	.type	.L.str.27,@object               // @.str.27
.L.str.27:
	.asciz	"Window changed"
	.size	.L.str.27, 15

	.type	.L.str.28,@object               // @.str.28
.L.str.28:
	.asciz	"I/O possible"
	.size	.L.str.28, 13

	.type	.L.str.29,@object               // @.str.29
.L.str.29:
	.asciz	"Power failure"
	.size	.L.str.29, 14

	.type	.L.str.30,@object               // @.str.30
.L.str.30:
	.asciz	"Bad system call"
	.size	.L.str.30, 16

	.type	__sys_siglist,@object           // @__sys_siglist
	.section	.data.rel.ro,"aw",@progbits
	.globl	__sys_siglist
	.p2align	3, 0x0
__sys_siglist:
	.xword	0
	.xword	.L.str
	.xword	.L.str.1
	.xword	.L.str.2
	.xword	.L.str.3
	.xword	.L.str.4
	.xword	.L.str.5
	.xword	.L.str.6
	.xword	.L.str.7
	.xword	.L.str.8
	.xword	.L.str.9
	.xword	.L.str.10
	.xword	.L.str.11
	.xword	.L.str.12
	.xword	.L.str.13
	.xword	.L.str.14
	.xword	.L.str.15
	.xword	.L.str.16
	.xword	.L.str.17
	.xword	.L.str.18
	.xword	.L.str.19
	.xword	.L.str.20
	.xword	.L.str.21
	.xword	.L.str.22
	.xword	.L.str.23
	.xword	.L.str.24
	.xword	.L.str.25
	.xword	.L.str.26
	.xword	.L.str.27
	.xword	.L.str.28
	.xword	.L.str.29
	.xword	.L.str.30
	.zero	264
	.size	__sys_siglist, 520

	.type	.L.str.31,@object               // @.str.31
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str.31:
	.asciz	"HUP"
	.size	.L.str.31, 4

	.type	.L.str.32,@object               // @.str.32
.L.str.32:
	.asciz	"INT"
	.size	.L.str.32, 4

	.type	.L.str.33,@object               // @.str.33
.L.str.33:
	.asciz	"QUIT"
	.size	.L.str.33, 5

	.type	.L.str.34,@object               // @.str.34
.L.str.34:
	.asciz	"ILL"
	.size	.L.str.34, 4

	.type	.L.str.35,@object               // @.str.35
.L.str.35:
	.asciz	"TRAP"
	.size	.L.str.35, 5

	.type	.L.str.36,@object               // @.str.36
.L.str.36:
	.asciz	"ABRT"
	.size	.L.str.36, 5

	.type	.L.str.37,@object               // @.str.37
.L.str.37:
	.asciz	"BUS"
	.size	.L.str.37, 4

	.type	.L.str.38,@object               // @.str.38
.L.str.38:
	.asciz	"FPE"
	.size	.L.str.38, 4

	.type	.L.str.39,@object               // @.str.39
.L.str.39:
	.asciz	"KILL"
	.size	.L.str.39, 5

	.type	.L.str.40,@object               // @.str.40
.L.str.40:
	.asciz	"USR1"
	.size	.L.str.40, 5

	.type	.L.str.41,@object               // @.str.41
.L.str.41:
	.asciz	"SEGV"
	.size	.L.str.41, 5

	.type	.L.str.42,@object               // @.str.42
.L.str.42:
	.asciz	"USR2"
	.size	.L.str.42, 5

	.type	.L.str.43,@object               // @.str.43
.L.str.43:
	.asciz	"PIPE"
	.size	.L.str.43, 5

	.type	.L.str.44,@object               // @.str.44
.L.str.44:
	.asciz	"ALRM"
	.size	.L.str.44, 5

	.type	.L.str.45,@object               // @.str.45
.L.str.45:
	.asciz	"TERM"
	.size	.L.str.45, 5

	.type	.L.str.46,@object               // @.str.46
.L.str.46:
	.asciz	"STKFLT"
	.size	.L.str.46, 7

	.type	.L.str.47,@object               // @.str.47
.L.str.47:
	.asciz	"CHLD"
	.size	.L.str.47, 5

	.type	.L.str.48,@object               // @.str.48
.L.str.48:
	.asciz	"CONT"
	.size	.L.str.48, 5

	.type	.L.str.49,@object               // @.str.49
.L.str.49:
	.asciz	"STOP"
	.size	.L.str.49, 5

	.type	.L.str.50,@object               // @.str.50
.L.str.50:
	.asciz	"TSTP"
	.size	.L.str.50, 5

	.type	.L.str.51,@object               // @.str.51
.L.str.51:
	.asciz	"TTIN"
	.size	.L.str.51, 5

	.type	.L.str.52,@object               // @.str.52
.L.str.52:
	.asciz	"TTOU"
	.size	.L.str.52, 5

	.type	.L.str.53,@object               // @.str.53
.L.str.53:
	.asciz	"URG"
	.size	.L.str.53, 4

	.type	.L.str.54,@object               // @.str.54
.L.str.54:
	.asciz	"XCPU"
	.size	.L.str.54, 5

	.type	.L.str.55,@object               // @.str.55
.L.str.55:
	.asciz	"XFSZ"
	.size	.L.str.55, 5

	.type	.L.str.56,@object               // @.str.56
.L.str.56:
	.asciz	"VTALRM"
	.size	.L.str.56, 7

	.type	.L.str.57,@object               // @.str.57
.L.str.57:
	.asciz	"PROF"
	.size	.L.str.57, 5

	.type	.L.str.58,@object               // @.str.58
.L.str.58:
	.asciz	"WINCH"
	.size	.L.str.58, 6

	.type	.L.str.59,@object               // @.str.59
.L.str.59:
	.asciz	"POLL"
	.size	.L.str.59, 5

	.type	.L.str.60,@object               // @.str.60
.L.str.60:
	.asciz	"PWR"
	.size	.L.str.60, 4

	.type	.L.str.61,@object               // @.str.61
.L.str.61:
	.asciz	"SYS"
	.size	.L.str.61, 4

	.type	__sys_sigabbrev,@object         // @__sys_sigabbrev
	.section	.data.rel.ro,"aw",@progbits
	.globl	__sys_sigabbrev
	.p2align	3, 0x0
__sys_sigabbrev:
	.xword	0
	.xword	.L.str.31
	.xword	.L.str.32
	.xword	.L.str.33
	.xword	.L.str.34
	.xword	.L.str.35
	.xword	.L.str.36
	.xword	.L.str.37
	.xword	.L.str.38
	.xword	.L.str.39
	.xword	.L.str.40
	.xword	.L.str.41
	.xword	.L.str.42
	.xword	.L.str.43
	.xword	.L.str.44
	.xword	.L.str.45
	.xword	.L.str.46
	.xword	.L.str.47
	.xword	.L.str.48
	.xword	.L.str.49
	.xword	.L.str.50
	.xword	.L.str.51
	.xword	.L.str.52
	.xword	.L.str.53
	.xword	.L.str.54
	.xword	.L.str.55
	.xword	.L.str.56
	.xword	.L.str.57
	.xword	.L.str.58
	.xword	.L.str.59
	.xword	.L.str.60
	.xword	.L.str.61
	.zero	264
	.size	__sys_sigabbrev, 520

	.ident	"clang version 23.1.0"
	.section	".note.GNU-stack","",@progbits
	.addrsig
