	.att_syntax
	.file	"errlist-data-gen.c"
                                        # Start of file scope inline assembly
mempcpy = __mempcpy
stpcpy = __stpcpy
                                        # End of file scope inline assembly
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"Success"
	.size	.L.str, 8

	.type	.L.str.1,@object                # @.str.1
.L.str.1:
	.asciz	"Operation not permitted"
	.size	.L.str.1, 24

	.type	.L.str.2,@object                # @.str.2
.L.str.2:
	.asciz	"No such file or directory"
	.size	.L.str.2, 26

	.type	.L.str.3,@object                # @.str.3
.L.str.3:
	.asciz	"No such process"
	.size	.L.str.3, 16

	.type	.L.str.4,@object                # @.str.4
.L.str.4:
	.asciz	"Interrupted system call"
	.size	.L.str.4, 24

	.type	.L.str.5,@object                # @.str.5
.L.str.5:
	.asciz	"Input/output error"
	.size	.L.str.5, 19

	.type	.L.str.6,@object                # @.str.6
.L.str.6:
	.asciz	"No such device or address"
	.size	.L.str.6, 26

	.type	.L.str.7,@object                # @.str.7
.L.str.7:
	.asciz	"Argument list too long"
	.size	.L.str.7, 23

	.type	.L.str.8,@object                # @.str.8
.L.str.8:
	.asciz	"Exec format error"
	.size	.L.str.8, 18

	.type	.L.str.9,@object                # @.str.9
.L.str.9:
	.asciz	"Bad file descriptor"
	.size	.L.str.9, 20

	.type	.L.str.10,@object               # @.str.10
.L.str.10:
	.asciz	"No child processes"
	.size	.L.str.10, 19

	.type	.L.str.11,@object               # @.str.11
.L.str.11:
	.asciz	"Resource temporarily unavailable"
	.size	.L.str.11, 33

	.type	.L.str.12,@object               # @.str.12
.L.str.12:
	.asciz	"Cannot allocate memory"
	.size	.L.str.12, 23

	.type	.L.str.13,@object               # @.str.13
.L.str.13:
	.asciz	"Permission denied"
	.size	.L.str.13, 18

	.type	.L.str.14,@object               # @.str.14
.L.str.14:
	.asciz	"Bad address"
	.size	.L.str.14, 12

	.type	.L.str.15,@object               # @.str.15
.L.str.15:
	.asciz	"Block device required"
	.size	.L.str.15, 22

	.type	.L.str.16,@object               # @.str.16
.L.str.16:
	.asciz	"Device or resource busy"
	.size	.L.str.16, 24

	.type	.L.str.17,@object               # @.str.17
.L.str.17:
	.asciz	"File exists"
	.size	.L.str.17, 12

	.type	.L.str.18,@object               # @.str.18
.L.str.18:
	.asciz	"Invalid cross-device link"
	.size	.L.str.18, 26

	.type	.L.str.19,@object               # @.str.19
.L.str.19:
	.asciz	"No such device"
	.size	.L.str.19, 15

	.type	.L.str.20,@object               # @.str.20
.L.str.20:
	.asciz	"Not a directory"
	.size	.L.str.20, 16

	.type	.L.str.21,@object               # @.str.21
.L.str.21:
	.asciz	"Is a directory"
	.size	.L.str.21, 15

	.type	.L.str.22,@object               # @.str.22
.L.str.22:
	.asciz	"Invalid argument"
	.size	.L.str.22, 17

	.type	.L.str.23,@object               # @.str.23
.L.str.23:
	.asciz	"Too many open files in system"
	.size	.L.str.23, 30

	.type	.L.str.24,@object               # @.str.24
.L.str.24:
	.asciz	"Too many open files"
	.size	.L.str.24, 20

	.type	.L.str.25,@object               # @.str.25
.L.str.25:
	.asciz	"Inappropriate ioctl for device"
	.size	.L.str.25, 31

	.type	.L.str.26,@object               # @.str.26
.L.str.26:
	.asciz	"Text file busy"
	.size	.L.str.26, 15

	.type	.L.str.27,@object               # @.str.27
.L.str.27:
	.asciz	"File too large"
	.size	.L.str.27, 15

	.type	.L.str.28,@object               # @.str.28
.L.str.28:
	.asciz	"No space left on device"
	.size	.L.str.28, 24

	.type	.L.str.29,@object               # @.str.29
.L.str.29:
	.asciz	"Illegal seek"
	.size	.L.str.29, 13

	.type	.L.str.30,@object               # @.str.30
.L.str.30:
	.asciz	"Read-only file system"
	.size	.L.str.30, 22

	.type	.L.str.31,@object               # @.str.31
.L.str.31:
	.asciz	"Too many links"
	.size	.L.str.31, 15

	.type	.L.str.32,@object               # @.str.32
.L.str.32:
	.asciz	"Broken pipe"
	.size	.L.str.32, 12

	.type	.L.str.33,@object               # @.str.33
.L.str.33:
	.asciz	"Numerical argument out of domain"
	.size	.L.str.33, 33

	.type	.L.str.34,@object               # @.str.34
.L.str.34:
	.asciz	"Numerical result out of range"
	.size	.L.str.34, 30

	.type	.L.str.35,@object               # @.str.35
.L.str.35:
	.asciz	"Resource deadlock avoided"
	.size	.L.str.35, 26

	.type	.L.str.36,@object               # @.str.36
.L.str.36:
	.asciz	"File name too long"
	.size	.L.str.36, 19

	.type	.L.str.37,@object               # @.str.37
.L.str.37:
	.asciz	"No locks available"
	.size	.L.str.37, 19

	.type	.L.str.38,@object               # @.str.38
.L.str.38:
	.asciz	"Function not implemented"
	.size	.L.str.38, 25

	.type	.L.str.39,@object               # @.str.39
.L.str.39:
	.asciz	"Directory not empty"
	.size	.L.str.39, 20

	.type	.L.str.40,@object               # @.str.40
.L.str.40:
	.asciz	"Too many levels of symbolic links"
	.size	.L.str.40, 34

	.type	.L.str.41,@object               # @.str.41
.L.str.41:
	.asciz	"No message of desired type"
	.size	.L.str.41, 27

	.type	.L.str.42,@object               # @.str.42
.L.str.42:
	.asciz	"Identifier removed"
	.size	.L.str.42, 19

	.type	.L.str.43,@object               # @.str.43
.L.str.43:
	.asciz	"Channel number out of range"
	.size	.L.str.43, 28

	.type	.L.str.44,@object               # @.str.44
.L.str.44:
	.asciz	"Level 2 not synchronized"
	.size	.L.str.44, 25

	.type	.L.str.45,@object               # @.str.45
.L.str.45:
	.asciz	"Level 3 halted"
	.size	.L.str.45, 15

	.type	.L.str.46,@object               # @.str.46
.L.str.46:
	.asciz	"Level 3 reset"
	.size	.L.str.46, 14

	.type	.L.str.47,@object               # @.str.47
.L.str.47:
	.asciz	"Link number out of range"
	.size	.L.str.47, 25

	.type	.L.str.48,@object               # @.str.48
.L.str.48:
	.asciz	"Protocol driver not attached"
	.size	.L.str.48, 29

	.type	.L.str.49,@object               # @.str.49
.L.str.49:
	.asciz	"No CSI structure available"
	.size	.L.str.49, 27

	.type	.L.str.50,@object               # @.str.50
.L.str.50:
	.asciz	"Level 2 halted"
	.size	.L.str.50, 15

	.type	.L.str.51,@object               # @.str.51
.L.str.51:
	.asciz	"Invalid exchange"
	.size	.L.str.51, 17

	.type	.L.str.52,@object               # @.str.52
.L.str.52:
	.asciz	"Invalid request descriptor"
	.size	.L.str.52, 27

	.type	.L.str.53,@object               # @.str.53
.L.str.53:
	.asciz	"Exchange full"
	.size	.L.str.53, 14

	.type	.L.str.54,@object               # @.str.54
.L.str.54:
	.asciz	"No anode"
	.size	.L.str.54, 9

	.type	.L.str.55,@object               # @.str.55
.L.str.55:
	.asciz	"Invalid request code"
	.size	.L.str.55, 21

	.type	.L.str.56,@object               # @.str.56
.L.str.56:
	.asciz	"Invalid slot"
	.size	.L.str.56, 13

	.type	.L.str.57,@object               # @.str.57
.L.str.57:
	.asciz	"Bad font file format"
	.size	.L.str.57, 21

	.type	.L.str.58,@object               # @.str.58
.L.str.58:
	.asciz	"Device not a stream"
	.size	.L.str.58, 20

	.type	.L.str.59,@object               # @.str.59
.L.str.59:
	.asciz	"No data available"
	.size	.L.str.59, 18

	.type	.L.str.60,@object               # @.str.60
.L.str.60:
	.asciz	"Timer expired"
	.size	.L.str.60, 14

	.type	.L.str.61,@object               # @.str.61
.L.str.61:
	.asciz	"Out of streams resources"
	.size	.L.str.61, 25

	.type	.L.str.62,@object               # @.str.62
.L.str.62:
	.asciz	"Machine is not on the network"
	.size	.L.str.62, 30

	.type	.L.str.63,@object               # @.str.63
.L.str.63:
	.asciz	"Package not installed"
	.size	.L.str.63, 22

	.type	.L.str.64,@object               # @.str.64
.L.str.64:
	.asciz	"Object is remote"
	.size	.L.str.64, 17

	.type	.L.str.65,@object               # @.str.65
.L.str.65:
	.asciz	"Link has been severed"
	.size	.L.str.65, 22

	.type	.L.str.66,@object               # @.str.66
.L.str.66:
	.asciz	"Advertise error"
	.size	.L.str.66, 16

	.type	.L.str.67,@object               # @.str.67
.L.str.67:
	.asciz	"Srmount error"
	.size	.L.str.67, 14

	.type	.L.str.68,@object               # @.str.68
.L.str.68:
	.asciz	"Communication error on send"
	.size	.L.str.68, 28

	.type	.L.str.69,@object               # @.str.69
.L.str.69:
	.asciz	"Protocol error"
	.size	.L.str.69, 15

	.type	.L.str.70,@object               # @.str.70
.L.str.70:
	.asciz	"Multihop attempted"
	.size	.L.str.70, 19

	.type	.L.str.71,@object               # @.str.71
.L.str.71:
	.asciz	"RFS specific error"
	.size	.L.str.71, 19

	.type	.L.str.72,@object               # @.str.72
.L.str.72:
	.asciz	"Bad message"
	.size	.L.str.72, 12

	.type	.L.str.73,@object               # @.str.73
.L.str.73:
	.asciz	"Value too large for defined data type"
	.size	.L.str.73, 38

	.type	.L.str.74,@object               # @.str.74
.L.str.74:
	.asciz	"Name not unique on network"
	.size	.L.str.74, 27

	.type	.L.str.75,@object               # @.str.75
.L.str.75:
	.asciz	"File descriptor in bad state"
	.size	.L.str.75, 29

	.type	.L.str.76,@object               # @.str.76
.L.str.76:
	.asciz	"Remote address changed"
	.size	.L.str.76, 23

	.type	.L.str.77,@object               # @.str.77
.L.str.77:
	.asciz	"Can not access a needed shared library"
	.size	.L.str.77, 39

	.type	.L.str.78,@object               # @.str.78
.L.str.78:
	.asciz	"Accessing a corrupted shared library"
	.size	.L.str.78, 37

	.type	.L.str.79,@object               # @.str.79
.L.str.79:
	.asciz	".lib section in a.out corrupted"
	.size	.L.str.79, 32

	.type	.L.str.80,@object               # @.str.80
.L.str.80:
	.asciz	"Attempting to link in too many shared libraries"
	.size	.L.str.80, 48

	.type	.L.str.81,@object               # @.str.81
.L.str.81:
	.asciz	"Cannot exec a shared library directly"
	.size	.L.str.81, 38

	.type	.L.str.82,@object               # @.str.82
.L.str.82:
	.asciz	"Invalid or incomplete multibyte or wide character"
	.size	.L.str.82, 50

	.type	.L.str.83,@object               # @.str.83
.L.str.83:
	.asciz	"Interrupted system call should be restarted"
	.size	.L.str.83, 44

	.type	.L.str.84,@object               # @.str.84
.L.str.84:
	.asciz	"Streams pipe error"
	.size	.L.str.84, 19

	.type	.L.str.85,@object               # @.str.85
.L.str.85:
	.asciz	"Too many users"
	.size	.L.str.85, 15

	.type	.L.str.86,@object               # @.str.86
.L.str.86:
	.asciz	"Socket operation on non-socket"
	.size	.L.str.86, 31

	.type	.L.str.87,@object               # @.str.87
.L.str.87:
	.asciz	"Destination address required"
	.size	.L.str.87, 29

	.type	.L.str.88,@object               # @.str.88
.L.str.88:
	.asciz	"Message too long"
	.size	.L.str.88, 17

	.type	.L.str.89,@object               # @.str.89
.L.str.89:
	.asciz	"Protocol wrong type for socket"
	.size	.L.str.89, 31

	.type	.L.str.90,@object               # @.str.90
.L.str.90:
	.asciz	"Protocol not available"
	.size	.L.str.90, 23

	.type	.L.str.91,@object               # @.str.91
.L.str.91:
	.asciz	"Protocol not supported"
	.size	.L.str.91, 23

	.type	.L.str.92,@object               # @.str.92
.L.str.92:
	.asciz	"Socket type not supported"
	.size	.L.str.92, 26

	.type	.L.str.93,@object               # @.str.93
.L.str.93:
	.asciz	"Operation not supported"
	.size	.L.str.93, 24

	.type	.L.str.94,@object               # @.str.94
.L.str.94:
	.asciz	"Protocol family not supported"
	.size	.L.str.94, 30

	.type	.L.str.95,@object               # @.str.95
.L.str.95:
	.asciz	"Address family not supported by protocol"
	.size	.L.str.95, 41

	.type	.L.str.96,@object               # @.str.96
.L.str.96:
	.asciz	"Address already in use"
	.size	.L.str.96, 23

	.type	.L.str.97,@object               # @.str.97
.L.str.97:
	.asciz	"Cannot assign requested address"
	.size	.L.str.97, 32

	.type	.L.str.98,@object               # @.str.98
.L.str.98:
	.asciz	"Network is down"
	.size	.L.str.98, 16

	.type	.L.str.99,@object               # @.str.99
.L.str.99:
	.asciz	"Network is unreachable"
	.size	.L.str.99, 23

	.type	.L.str.100,@object              # @.str.100
.L.str.100:
	.asciz	"Network dropped connection on reset"
	.size	.L.str.100, 36

	.type	.L.str.101,@object              # @.str.101
.L.str.101:
	.asciz	"Software caused connection abort"
	.size	.L.str.101, 33

	.type	.L.str.102,@object              # @.str.102
.L.str.102:
	.asciz	"Connection reset by peer"
	.size	.L.str.102, 25

	.type	.L.str.103,@object              # @.str.103
.L.str.103:
	.asciz	"No buffer space available"
	.size	.L.str.103, 26

	.type	.L.str.104,@object              # @.str.104
.L.str.104:
	.asciz	"Transport endpoint is already connected"
	.size	.L.str.104, 40

	.type	.L.str.105,@object              # @.str.105
.L.str.105:
	.asciz	"Transport endpoint is not connected"
	.size	.L.str.105, 36

	.type	.L.str.106,@object              # @.str.106
.L.str.106:
	.asciz	"Cannot send after transport endpoint shutdown"
	.size	.L.str.106, 46

	.type	.L.str.107,@object              # @.str.107
.L.str.107:
	.asciz	"Too many references: cannot splice"
	.size	.L.str.107, 35

	.type	.L.str.108,@object              # @.str.108
.L.str.108:
	.asciz	"Connection timed out"
	.size	.L.str.108, 21

	.type	.L.str.109,@object              # @.str.109
.L.str.109:
	.asciz	"Connection refused"
	.size	.L.str.109, 19

	.type	.L.str.110,@object              # @.str.110
.L.str.110:
	.asciz	"Host is down"
	.size	.L.str.110, 13

	.type	.L.str.111,@object              # @.str.111
.L.str.111:
	.asciz	"No route to host"
	.size	.L.str.111, 17

	.type	.L.str.112,@object              # @.str.112
.L.str.112:
	.asciz	"Operation already in progress"
	.size	.L.str.112, 30

	.type	.L.str.113,@object              # @.str.113
.L.str.113:
	.asciz	"Operation now in progress"
	.size	.L.str.113, 26

	.type	.L.str.114,@object              # @.str.114
.L.str.114:
	.asciz	"Stale file handle"
	.size	.L.str.114, 18

	.type	.L.str.115,@object              # @.str.115
.L.str.115:
	.asciz	"Structure needs cleaning"
	.size	.L.str.115, 25

	.type	.L.str.116,@object              # @.str.116
.L.str.116:
	.asciz	"Not a XENIX named type file"
	.size	.L.str.116, 28

	.type	.L.str.117,@object              # @.str.117
.L.str.117:
	.asciz	"No XENIX semaphores available"
	.size	.L.str.117, 30

	.type	.L.str.118,@object              # @.str.118
.L.str.118:
	.asciz	"Is a named type file"
	.size	.L.str.118, 21

	.type	.L.str.119,@object              # @.str.119
.L.str.119:
	.asciz	"Remote I/O error"
	.size	.L.str.119, 17

	.type	.L.str.120,@object              # @.str.120
.L.str.120:
	.asciz	"Disk quota exceeded"
	.size	.L.str.120, 20

	.type	.L.str.121,@object              # @.str.121
.L.str.121:
	.asciz	"No medium found"
	.size	.L.str.121, 16

	.type	.L.str.122,@object              # @.str.122
.L.str.122:
	.asciz	"Wrong medium type"
	.size	.L.str.122, 18

	.type	.L.str.123,@object              # @.str.123
.L.str.123:
	.asciz	"Operation canceled"
	.size	.L.str.123, 19

	.type	.L.str.124,@object              # @.str.124
.L.str.124:
	.asciz	"Required key not available"
	.size	.L.str.124, 27

	.type	.L.str.125,@object              # @.str.125
.L.str.125:
	.asciz	"Key has expired"
	.size	.L.str.125, 16

	.type	.L.str.126,@object              # @.str.126
.L.str.126:
	.asciz	"Key has been revoked"
	.size	.L.str.126, 21

	.type	.L.str.127,@object              # @.str.127
.L.str.127:
	.asciz	"Key was rejected by service"
	.size	.L.str.127, 28

	.type	.L.str.128,@object              # @.str.128
.L.str.128:
	.asciz	"Owner died"
	.size	.L.str.128, 11

	.type	.L.str.129,@object              # @.str.129
.L.str.129:
	.asciz	"State not recoverable"
	.size	.L.str.129, 22

	.type	.L.str.130,@object              # @.str.130
.L.str.130:
	.asciz	"Operation not possible due to RF-kill"
	.size	.L.str.130, 38

	.type	.L.str.131,@object              # @.str.131
.L.str.131:
	.asciz	"Memory page has hardware error"
	.size	.L.str.131, 31

	.type	_sys_errlist_internal,@object   # @_sys_errlist_internal
	.section	.data.rel.ro,"aw",@progbits
	.globl	_sys_errlist_internal
	.p2align	4, 0x0
_sys_errlist_internal:
	.quad	.L.str
	.quad	.L.str.1
	.quad	.L.str.2
	.quad	.L.str.3
	.quad	.L.str.4
	.quad	.L.str.5
	.quad	.L.str.6
	.quad	.L.str.7
	.quad	.L.str.8
	.quad	.L.str.9
	.quad	.L.str.10
	.quad	.L.str.11
	.quad	.L.str.12
	.quad	.L.str.13
	.quad	.L.str.14
	.quad	.L.str.15
	.quad	.L.str.16
	.quad	.L.str.17
	.quad	.L.str.18
	.quad	.L.str.19
	.quad	.L.str.20
	.quad	.L.str.21
	.quad	.L.str.22
	.quad	.L.str.23
	.quad	.L.str.24
	.quad	.L.str.25
	.quad	.L.str.26
	.quad	.L.str.27
	.quad	.L.str.28
	.quad	.L.str.29
	.quad	.L.str.30
	.quad	.L.str.31
	.quad	.L.str.32
	.quad	.L.str.33
	.quad	.L.str.34
	.quad	.L.str.35
	.quad	.L.str.36
	.quad	.L.str.37
	.quad	.L.str.38
	.quad	.L.str.39
	.quad	.L.str.40
	.quad	0
	.quad	.L.str.41
	.quad	.L.str.42
	.quad	.L.str.43
	.quad	.L.str.44
	.quad	.L.str.45
	.quad	.L.str.46
	.quad	.L.str.47
	.quad	.L.str.48
	.quad	.L.str.49
	.quad	.L.str.50
	.quad	.L.str.51
	.quad	.L.str.52
	.quad	.L.str.53
	.quad	.L.str.54
	.quad	.L.str.55
	.quad	.L.str.56
	.quad	0
	.quad	.L.str.57
	.quad	.L.str.58
	.quad	.L.str.59
	.quad	.L.str.60
	.quad	.L.str.61
	.quad	.L.str.62
	.quad	.L.str.63
	.quad	.L.str.64
	.quad	.L.str.65
	.quad	.L.str.66
	.quad	.L.str.67
	.quad	.L.str.68
	.quad	.L.str.69
	.quad	.L.str.70
	.quad	.L.str.71
	.quad	.L.str.72
	.quad	.L.str.73
	.quad	.L.str.74
	.quad	.L.str.75
	.quad	.L.str.76
	.quad	.L.str.77
	.quad	.L.str.78
	.quad	.L.str.79
	.quad	.L.str.80
	.quad	.L.str.81
	.quad	.L.str.82
	.quad	.L.str.83
	.quad	.L.str.84
	.quad	.L.str.85
	.quad	.L.str.86
	.quad	.L.str.87
	.quad	.L.str.88
	.quad	.L.str.89
	.quad	.L.str.90
	.quad	.L.str.91
	.quad	.L.str.92
	.quad	.L.str.93
	.quad	.L.str.94
	.quad	.L.str.95
	.quad	.L.str.96
	.quad	.L.str.97
	.quad	.L.str.98
	.quad	.L.str.99
	.quad	.L.str.100
	.quad	.L.str.101
	.quad	.L.str.102
	.quad	.L.str.103
	.quad	.L.str.104
	.quad	.L.str.105
	.quad	.L.str.106
	.quad	.L.str.107
	.quad	.L.str.108
	.quad	.L.str.109
	.quad	.L.str.110
	.quad	.L.str.111
	.quad	.L.str.112
	.quad	.L.str.113
	.quad	.L.str.114
	.quad	.L.str.115
	.quad	.L.str.116
	.quad	.L.str.117
	.quad	.L.str.118
	.quad	.L.str.119
	.quad	.L.str.120
	.quad	.L.str.121
	.quad	.L.str.122
	.quad	.L.str.123
	.quad	.L.str.124
	.quad	.L.str.125
	.quad	.L.str.126
	.quad	.L.str.127
	.quad	.L.str.128
	.quad	.L.str.129
	.quad	.L.str.130
	.quad	.L.str.131
	.size	_sys_errlist_internal, 1072

	.type	_sys_errlist_internal_len,@object # @_sys_errlist_internal_len
	.section	.rodata,"a",@progbits
	.globl	_sys_errlist_internal_len
	.p2align	3, 0x0
_sys_errlist_internal_len:
	.quad	134                             # 0x86
	.size	_sys_errlist_internal_len, 8

	.ident	"clang version 23.1.0"
	.section	".note.GNU-stack","",@progbits
	.addrsig
