#define GCCMACROARM_PCREL_MOVW_OK 0
#define GCCMACROASM_LINE_SEP ;
#define GCCMACROBUILD_PIE_DEFAULT 0
#define GCCMACROC_SYMBOL_NAME(name) name
#define GCCMACRODEFAULT_DL_X86_CET_CONTROL cet_elf_property
#define GCCMACRODIAG_IGNORE_NEEDS_COMMENT(version,option) _Pragma (_DIAG_STR (GCC diagnostic ignored option))
#define GCCMACRODIAG_IGNORE_NEEDS_COMMENT_CLANG(version,option) _Pragma (_DIAG_STR (clang diagnostic ignored option))
#define GCCMACRODIAG_IGNORE_NEEDS_COMMENT_GCC(VERSION,WARNING) 
#define GCCMACRODIAG_IGNORE_Os_NEEDS_COMMENT(version,option) 
#define GCCMACRODIAG_IGNORE_Os_NEEDS_COMMENT_GCC(VERSION,WARNING) 
#define GCCMACRODIAG_POP_NEEDS_COMMENT _Pragma ("GCC diagnostic pop")
#define GCCMACRODIAG_POP_NEEDS_COMMENT_CLANG _Pragma ("clang diagnostic pop")
#define GCCMACRODIAG_PUSH_NEEDS_COMMENT _Pragma ("GCC diagnostic push")
#define GCCMACRODIAG_PUSH_NEEDS_COMMENT_CLANG _Pragma ("clang diagnostic push")
#define GCCMACROENABLE_NLS 1
#define GCCMACROENABLE_SFRAME 0
#define GCCMACROENABLE_STATIC_PIE 1
#define GCCMACROHAVE_64B_ATOMICS 1
#define GCCMACROHAVE_ASM_SET_DIRECTIVE 1
#define GCCMACROHAVE_BUILTIN_EXPECT 1
#define GCCMACROHAVE_BUILTIN_TRAP 1
#define GCCMACROHAVE_CC_NO_STACK_PROTECTOR 1
#define GCCMACROHAVE_CONFIG_H 0
#define GCCMACROHAVE_GCC_IFUNC 1
#define GCCMACROHAVE_GNU_RETAIN 1
#define GCCMACROHAVE_IFUNC 1
#define GCCMACROHAVE_INLINED_SYSCALLS 1
#define GCCMACROHAVE_ISWCTYPE 1
#define GCCMACROHAVE_LIBINTL_H 1
#define GCCMACROHAVE_MBSRTOWCS 1
#define GCCMACROHAVE_MBSTATE_T 1
#define GCCMACROHAVE_MEMPCPY 1
#define GCCMACROHAVE_PPC_FCFID 0
#define GCCMACROHAVE_PPC_FCTIDZ 0
#define GCCMACROHAVE_PT_CHOWN 0
#define GCCMACROHAVE_REGEX 1
#define GCCMACROHAVE_SFP_HANDLE_EXCEPTIONS 1
#define GCCMACROHAVE_TEST_CC_NO_STACK_PROTECTOR 1
#define GCCMACROHAVE_WCTYPE_H 1
#define GCCMACROHAVE_X86_INLINE_FMOD 0
#define GCCMACROHAVE_X86_INLINE_TRUNC 1
#define GCCMACROHAVE_X86_LIBGCC_CMP_RETURN_ATTR 0
#define GCCMACROINCLUDE_X86_ISA_LEVEL 1
#define GCCMACROIN_MODULE PASTE_NAME (MODULE_, MODULE_NAME)
#define GCCMACROIS_IN(lib) (IN_MODULE == MODULE_##lib)
#define GCCMACROIS_IN_LIB (IN_MODULE > MODULE_LIBS_BEGIN)
#define GCCMACROMINIMUM_X86_ISA_LEVEL 1
#define GCCMACROMODULE_LIBS_BEGIN 16
#define GCCMACROMODULE_NAME libc
#define GCCMACROMODULE_extramodules 11
#define GCCMACROMODULE_iconvdata 2
#define GCCMACROMODULE_iconvprogs 1
#define GCCMACROMODULE_ldconfig 3
#define GCCMACROMODULE_libBrokenLocale 19
#define GCCMACROMODULE_libanl 38
#define GCCMACROMODULE_libc 18
#define GCCMACROMODULE_libc_malloc_debug 25
#define GCCMACROMODULE_libdl 22
#define GCCMACROMODULE_libgcc_s 23
#define GCCMACROMODULE_libm 34
#define GCCMACROMODULE_libmemusage 4
#define GCCMACROMODULE_libmvec 30
#define GCCMACROMODULE_libnldbl 12
#define GCCMACROMODULE_libnsl 24
#define GCCMACROMODULE_libnss_compat 29
#define GCCMACROMODULE_libnss_db 32
#define GCCMACROMODULE_libnss_dns 28
#define GCCMACROMODULE_libnss_files 35
#define GCCMACROMODULE_libnss_hesiod 37
#define GCCMACROMODULE_libnss_ldap 27
#define GCCMACROMODULE_libpcprofile 5
#define GCCMACROMODULE_libpthread 20
#define GCCMACROMODULE_libresolv 31
#define GCCMACROMODULE_librpcsvc 6
#define GCCMACROMODULE_librt 36
#define GCCMACROMODULE_libsupport 13
#define GCCMACROMODULE_libthread_db 21
#define GCCMACROMODULE_libunwind 33
#define GCCMACROMODULE_libutil 26
#define GCCMACROMODULE_locale_programs 7
#define GCCMACROMODULE_memusagestat 8
#define GCCMACROMODULE_nonlib 9
#define GCCMACROMODULE_nscd 10
#define GCCMACROMODULE_rtld 17
#define GCCMACROMODULE_testsuite 14
#define GCCMACROMODULE_testsuite_internal 15
#define GCCMACROPASTE_NAME(a,b) PASTE_NAME1 (a,b)
#define GCCMACROPASTE_NAME1(a,b) a##b
#define GCCMACROPKGVERSION "(GNU libc) "
#define GCCMACROREPORT_BUGS_TO "<https://www.gnu.org/software/libc/bugs.html>"
#define GCCMACRORETURN_ADDRESS(nr) __builtin_extract_return_addr (__builtin_return_address (nr))
#define GCCMACROSTACK_PROTECTOR_LEVEL 0
#define GCCMACROSTDC_HEADERS 1
#define GCCMACROSUPPORT_STATIC_PIE 1
#define GCCMACROSYMVER_NEEDS_ALIAS 0
#define GCCMACROTIMEOUTFACTOR 1
#define GCCMACROTOP_NAMESPACE glibc
#define GCCMACROUSE_LDCONFIG 1
#define GCCMACROUSE_MULTIARCH 1
#define GCCMACROUSE_PPC_SCV 1
#define GCCMACRO_DIAG_STR(s) _DIAG_STR1(s)
#define GCCMACRO_DIAG_STR1(s) #s
#define GCCMACRO_GL_ATTRIBUTE_CONST __attribute__ ((__const__))
#define GCCMACRO_GL_ATTRIBUTE_PURE __attribute__ ((__pure__))
#define GCCMACRO_GL_UNUSED __attribute__ ((__unused__))
#define GCCMACRO_GL_UNUSED_LABEL _GL_UNUSED
#define GCCMACRO_GNU_SOURCE 1
#define GCCMACRO_INCLUDE_MISC_H 
#define GCCMACRO_LIBC 1
#define GCCMACRO_LIBC_DIAG_H 1
#define GCCMACRO_LIBC_REENTRANT 1
#define GCCMACRO_LIBC_SYMBOLS_H 1
#define GCCMACRO_LIBC_SYMVER_H 1
#define GCCMACRO_LP64 1
#define GCCMACRO__ABI_TAG_VERSION 4,19,0
#define GCCMACRO__ATOMIC_ACQUIRE 2
#define GCCMACRO__ATOMIC_ACQ_REL 4
#define GCCMACRO__ATOMIC_CONSUME 1
#define GCCMACRO__ATOMIC_RELAXED 0
#define GCCMACRO__ATOMIC_RELEASE 3
#define GCCMACRO__ATOMIC_SEQ_CST 5
#define GCCMACRO__BIGGEST_ALIGNMENT__ 16
#define GCCMACRO__BITINT_MAXWIDTH__ 8388608
#define GCCMACRO__BOOL_WIDTH__ 1
#define GCCMACRO__BYTE_ORDER__ __ORDER_LITTLE_ENDIAN__
#define GCCMACRO__CHAR16_TYPE__ unsigned short
#define GCCMACRO__CHAR32_TYPE__ unsigned int
#define GCCMACRO__CHAR_BIT__ 8
#define GCCMACRO__CLANG_ATOMIC_BOOL_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_CHAR16_T_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_CHAR32_T_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_CHAR_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_INT_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_LLONG_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_LONG_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_POINTER_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_SHORT_LOCK_FREE 2
#define GCCMACRO__CLANG_ATOMIC_WCHAR_T_LOCK_FREE 2
#define GCCMACRO__CONSTANT_CFSTRINGS__ 1
#define GCCMACRO__DBL_DECIMAL_DIG__ 17
#define GCCMACRO__DBL_DENORM_MIN__ 4.9406564584124654e-324
#define GCCMACRO__DBL_DIG__ 15
#define GCCMACRO__DBL_EPSILON__ 2.2204460492503131e-16
#define GCCMACRO__DBL_HAS_DENORM__ 1
#define GCCMACRO__DBL_HAS_INFINITY__ 1
#define GCCMACRO__DBL_HAS_QUIET_NAN__ 1
#define GCCMACRO__DBL_MANT_DIG__ 53
#define GCCMACRO__DBL_MAX_10_EXP__ 308
#define GCCMACRO__DBL_MAX_EXP__ 1024
#define GCCMACRO__DBL_MAX__ 1.7976931348623157e+308
#define GCCMACRO__DBL_MIN_10_EXP__ (-307)
#define GCCMACRO__DBL_MIN_EXP__ (-1021)
#define GCCMACRO__DBL_MIN__ 2.2250738585072014e-308
#define GCCMACRO__DBL_NORM_MAX__ 1.7976931348623157e+308
#define GCCMACRO__DECIMAL_DIG__ __LDBL_DECIMAL_DIG__
#define GCCMACRO__ELF__ 1
#define GCCMACRO__FINITE_MATH_ONLY__ 0
#define GCCMACRO__FLOAT128__ 1
#define GCCMACRO__FLT16_DECIMAL_DIG__ 5
#define GCCMACRO__FLT16_DENORM_MIN__ 5.9604644775390625e-8F16
#define GCCMACRO__FLT16_DIG__ 3
#define GCCMACRO__FLT16_EPSILON__ 9.765625e-4F16
#define GCCMACRO__FLT16_HAS_DENORM__ 1
#define GCCMACRO__FLT16_HAS_INFINITY__ 1
#define GCCMACRO__FLT16_HAS_QUIET_NAN__ 1
#define GCCMACRO__FLT16_MANT_DIG__ 11
#define GCCMACRO__FLT16_MAX_10_EXP__ 4
#define GCCMACRO__FLT16_MAX_EXP__ 16
#define GCCMACRO__FLT16_MAX__ 6.5504e+4F16
#define GCCMACRO__FLT16_MIN_10_EXP__ (-4)
#define GCCMACRO__FLT16_MIN_EXP__ (-13)
#define GCCMACRO__FLT16_MIN__ 6.103515625e-5F16
#define GCCMACRO__FLT16_NORM_MAX__ 6.5504e+4F16
#define GCCMACRO__FLT_DECIMAL_DIG__ 9
#define GCCMACRO__FLT_DENORM_MIN__ 1.40129846e-45F
#define GCCMACRO__FLT_DIG__ 6
#define GCCMACRO__FLT_EPSILON__ 1.19209290e-7F
#define GCCMACRO__FLT_HAS_DENORM__ 1
#define GCCMACRO__FLT_HAS_INFINITY__ 1
#define GCCMACRO__FLT_HAS_QUIET_NAN__ 1
#define GCCMACRO__FLT_MANT_DIG__ 24
#define GCCMACRO__FLT_MAX_10_EXP__ 38
#define GCCMACRO__FLT_MAX_EXP__ 128
#define GCCMACRO__FLT_MAX__ 3.40282347e+38F
#define GCCMACRO__FLT_MIN_10_EXP__ (-37)
#define GCCMACRO__FLT_MIN_EXP__ (-125)
#define GCCMACRO__FLT_MIN__ 1.17549435e-38F
#define GCCMACRO__FLT_NORM_MAX__ 3.40282347e+38F
#define GCCMACRO__FLT_RADIX__ 2
#define GCCMACRO__FPCLASS_NEGINF 0x0004
#define GCCMACRO__FPCLASS_NEGNORMAL 0x0008
#define GCCMACRO__FPCLASS_NEGSUBNORMAL 0x0010
#define GCCMACRO__FPCLASS_NEGZERO 0x0020
#define GCCMACRO__FPCLASS_POSINF 0x0200
#define GCCMACRO__FPCLASS_POSNORMAL 0x0100
#define GCCMACRO__FPCLASS_POSSUBNORMAL 0x0080
#define GCCMACRO__FPCLASS_POSZERO 0x0040
#define GCCMACRO__FPCLASS_QNAN 0x0002
#define GCCMACRO__FPCLASS_SNAN 0x0001
#define GCCMACRO__FXSR__ 1
#define GCCMACRO__GCC_ASM_FLAG_OUTPUTS__ 1
#define GCCMACRO__GCC_ATOMIC_BOOL_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_CHAR16_T_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_CHAR32_T_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_CHAR_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_INT_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_LLONG_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_LONG_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_POINTER_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_SHORT_LOCK_FREE 2
#define GCCMACRO__GCC_ATOMIC_TEST_AND_SET_TRUEVAL 1
#define GCCMACRO__GCC_ATOMIC_WCHAR_T_LOCK_FREE 2
#define GCCMACRO__GCC_CONSTRUCTIVE_SIZE 64
#define GCCMACRO__GCC_DESTRUCTIVE_SIZE 64
#define GCCMACRO__GCC_HAVE_DWARF2_CFI_ASM 1
#define GCCMACRO__GCC_HAVE_SYNC_COMPARE_AND_SWAP_1 1
#define GCCMACRO__GCC_HAVE_SYNC_COMPARE_AND_SWAP_2 1
#define GCCMACRO__GCC_HAVE_SYNC_COMPARE_AND_SWAP_4 1
#define GCCMACRO__GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 1
#define GCCMACRO__GNUC_GNU_INLINE__ 1
#define GCCMACRO__GNUC_MINOR__ 2
#define GCCMACRO__GNUC_PATCHLEVEL__ 1
#define GCCMACRO__GNUC__ 4
#define GCCMACRO__GXX_ABI_VERSION 1002
#define GCCMACRO__INT16_C(c) c
#define GCCMACRO__INT16_C_SUFFIX__ 
#define GCCMACRO__INT16_FMTd__ "hd"
#define GCCMACRO__INT16_FMTi__ "hi"
#define GCCMACRO__INT16_MAX__ 32767
#define GCCMACRO__INT16_TYPE__ short
#define GCCMACRO__INT32_C(c) c
#define GCCMACRO__INT32_C_SUFFIX__ 
#define GCCMACRO__INT32_FMTd__ "d"
#define GCCMACRO__INT32_FMTi__ "i"
#define GCCMACRO__INT32_MAX__ 2147483647
#define GCCMACRO__INT32_TYPE__ int
#define GCCMACRO__INT64_C(c) c##L
#define GCCMACRO__INT64_C_SUFFIX__ L
#define GCCMACRO__INT64_FMTd__ "ld"
#define GCCMACRO__INT64_FMTi__ "li"
#define GCCMACRO__INT64_MAX__ 9223372036854775807L
#define GCCMACRO__INT64_TYPE__ long int
#define GCCMACRO__INT8_C(c) c
#define GCCMACRO__INT8_C_SUFFIX__ 
#define GCCMACRO__INT8_FMTd__ "hhd"
#define GCCMACRO__INT8_FMTi__ "hhi"
#define GCCMACRO__INT8_MAX__ 127
#define GCCMACRO__INT8_TYPE__ signed char
#define GCCMACRO__INTMAX_C(c) c##L
#define GCCMACRO__INTMAX_C_SUFFIX__ L
#define GCCMACRO__INTMAX_FMTd__ "ld"
#define GCCMACRO__INTMAX_FMTi__ "li"
#define GCCMACRO__INTMAX_MAX__ 9223372036854775807L
#define GCCMACRO__INTMAX_TYPE__ long int
#define GCCMACRO__INTMAX_WIDTH__ 64
#define GCCMACRO__INTPTR_FMTd__ "ld"
#define GCCMACRO__INTPTR_FMTi__ "li"
#define GCCMACRO__INTPTR_MAX__ 9223372036854775807L
#define GCCMACRO__INTPTR_TYPE__ long int
#define GCCMACRO__INTPTR_WIDTH__ 64
#define GCCMACRO__INT_FAST16_FMTd__ "hd"
#define GCCMACRO__INT_FAST16_FMTi__ "hi"
#define GCCMACRO__INT_FAST16_MAX__ 32767
#define GCCMACRO__INT_FAST16_TYPE__ short
#define GCCMACRO__INT_FAST16_WIDTH__ 16
#define GCCMACRO__INT_FAST32_FMTd__ "d"
#define GCCMACRO__INT_FAST32_FMTi__ "i"
#define GCCMACRO__INT_FAST32_MAX__ 2147483647
#define GCCMACRO__INT_FAST32_TYPE__ int
#define GCCMACRO__INT_FAST32_WIDTH__ 32
#define GCCMACRO__INT_FAST64_FMTd__ "ld"
#define GCCMACRO__INT_FAST64_FMTi__ "li"
#define GCCMACRO__INT_FAST64_MAX__ 9223372036854775807L
#define GCCMACRO__INT_FAST64_TYPE__ long int
#define GCCMACRO__INT_FAST64_WIDTH__ 64
#define GCCMACRO__INT_FAST8_FMTd__ "hhd"
#define GCCMACRO__INT_FAST8_FMTi__ "hhi"
#define GCCMACRO__INT_FAST8_MAX__ 127
#define GCCMACRO__INT_FAST8_TYPE__ signed char
#define GCCMACRO__INT_FAST8_WIDTH__ 8
#define GCCMACRO__INT_LEAST16_FMTd__ "hd"
#define GCCMACRO__INT_LEAST16_FMTi__ "hi"
#define GCCMACRO__INT_LEAST16_MAX__ 32767
#define GCCMACRO__INT_LEAST16_TYPE__ short
#define GCCMACRO__INT_LEAST16_WIDTH__ 16
#define GCCMACRO__INT_LEAST32_FMTd__ "d"
#define GCCMACRO__INT_LEAST32_FMTi__ "i"
#define GCCMACRO__INT_LEAST32_MAX__ 2147483647
#define GCCMACRO__INT_LEAST32_TYPE__ int
#define GCCMACRO__INT_LEAST32_WIDTH__ 32
#define GCCMACRO__INT_LEAST64_FMTd__ "ld"
#define GCCMACRO__INT_LEAST64_FMTi__ "li"
#define GCCMACRO__INT_LEAST64_MAX__ 9223372036854775807L
#define GCCMACRO__INT_LEAST64_TYPE__ long int
#define GCCMACRO__INT_LEAST64_WIDTH__ 64
#define GCCMACRO__INT_LEAST8_FMTd__ "hhd"
#define GCCMACRO__INT_LEAST8_FMTi__ "hhi"
#define GCCMACRO__INT_LEAST8_MAX__ 127
#define GCCMACRO__INT_LEAST8_TYPE__ signed char
#define GCCMACRO__INT_LEAST8_WIDTH__ 8
#define GCCMACRO__INT_MAX__ 2147483647
#define GCCMACRO__INT_WIDTH__ 32
#define GCCMACRO__LDBL_DECIMAL_DIG__ 21
#define GCCMACRO__LDBL_DENORM_MIN__ 3.64519953188247460253e-4951L
#define GCCMACRO__LDBL_DIG__ 18
#define GCCMACRO__LDBL_EPSILON__ 1.08420217248550443401e-19L
#define GCCMACRO__LDBL_HAS_DENORM__ 1
#define GCCMACRO__LDBL_HAS_INFINITY__ 1
#define GCCMACRO__LDBL_HAS_QUIET_NAN__ 1
#define GCCMACRO__LDBL_MANT_DIG__ 64
#define GCCMACRO__LDBL_MAX_10_EXP__ 4932
#define GCCMACRO__LDBL_MAX_EXP__ 16384
#define GCCMACRO__LDBL_MAX__ 1.18973149535723176502e+4932L
#define GCCMACRO__LDBL_MIN_10_EXP__ (-4931)
#define GCCMACRO__LDBL_MIN_EXP__ (-16381)
#define GCCMACRO__LDBL_MIN__ 3.36210314311209350626e-4932L
#define GCCMACRO__LDBL_NORM_MAX__ 1.18973149535723176502e+4932L
#define GCCMACRO__LINUX_KERNEL_VERSION (4 * 65536 + 19 * 256 + 0)
#define GCCMACRO__LINUX_KERNEL_VERSION_STR "4.19.0"
#define GCCMACRO__LITTLE_ENDIAN__ 1
#define GCCMACRO__LLONG_WIDTH__ 64
#define GCCMACRO__LONG_LONG_MAX__ 9223372036854775807LL
#define GCCMACRO__LONG_MAX__ 9223372036854775807L
#define GCCMACRO__LONG_WIDTH__ 64
#define GCCMACRO__LP64__ 1
#define GCCMACRO__MEMORY_SCOPE_CLUSTR 5
#define GCCMACRO__MEMORY_SCOPE_DEVICE 1
#define GCCMACRO__MEMORY_SCOPE_SINGLE 4
#define GCCMACRO__MEMORY_SCOPE_SYSTEM 0
#define GCCMACRO__MEMORY_SCOPE_WRKGRP 2
#define GCCMACRO__MEMORY_SCOPE_WVFRNT 3
#define GCCMACRO__MMX__ 1
#define GCCMACRO__NO_MATH_INLINES 1
#define GCCMACRO__OBJC_BOOL_IS_BOOL 0
#define GCCMACRO__OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES 3
#define GCCMACRO__OPENCL_MEMORY_SCOPE_DEVICE 2
#define GCCMACRO__OPENCL_MEMORY_SCOPE_SUB_GROUP 4
#define GCCMACRO__OPENCL_MEMORY_SCOPE_WORK_GROUP 1
#define GCCMACRO__OPENCL_MEMORY_SCOPE_WORK_ITEM 0
#define GCCMACRO__OPTIMIZE__ 1
#define GCCMACRO__ORDER_BIG_ENDIAN__ 4321
#define GCCMACRO__ORDER_LITTLE_ENDIAN__ 1234
#define GCCMACRO__ORDER_PDP_ENDIAN__ 3412
#define GCCMACRO__PIC__ 2
#define GCCMACRO__PIE__ 2
#define GCCMACRO__POINTER_WIDTH__ 64
#define GCCMACRO__PRAGMA_REDEFINE_EXTNAME 1
#define GCCMACRO__PTHREAD_HTL 0
#define GCCMACRO__PTHREAD_NPTL 1
#define GCCMACRO__PTRDIFF_FMTd__ "ld"
#define GCCMACRO__PTRDIFF_FMTi__ "li"
#define GCCMACRO__PTRDIFF_MAX__ 9223372036854775807L
#define GCCMACRO__PTRDIFF_TYPE__ long int
#define GCCMACRO__PTRDIFF_WIDTH__ 64
#define GCCMACRO__REGISTER_PREFIX__ 
#define GCCMACRO__SCHAR_MAX__ 127
#define GCCMACRO__SEG_FS 1
#define GCCMACRO__SEG_GS 1
#define GCCMACRO__SHRT_MAX__ 32767
#define GCCMACRO__SHRT_WIDTH__ 16
#define GCCMACRO__SIG_ATOMIC_MAX__ 2147483647
#define GCCMACRO__SIG_ATOMIC_MIN__ (-__SIG_ATOMIC_MAX__ - 1)
#define GCCMACRO__SIG_ATOMIC_TYPE__ int
#define GCCMACRO__SIG_ATOMIC_WIDTH__ 32
#define GCCMACRO__SIZEOF_DOUBLE__ 8
#define GCCMACRO__SIZEOF_FLOAT128__ 16
#define GCCMACRO__SIZEOF_FLOAT__ 4
#define GCCMACRO__SIZEOF_INT128__ 16
#define GCCMACRO__SIZEOF_INT__ 4
#define GCCMACRO__SIZEOF_LONG_DOUBLE__ 16
#define GCCMACRO__SIZEOF_LONG_LONG__ 8
#define GCCMACRO__SIZEOF_LONG__ 8
#define GCCMACRO__SIZEOF_POINTER__ 8
#define GCCMACRO__SIZEOF_PTRDIFF_T__ 8
#define GCCMACRO__SIZEOF_SHORT__ 2
#define GCCMACRO__SIZEOF_SIZE_T__ 8
#define GCCMACRO__SIZEOF_WCHAR_T__ 4
#define GCCMACRO__SIZEOF_WINT_T__ 4
#define GCCMACRO__SIZE_FMTX__ "lX"
#define GCCMACRO__SIZE_FMTo__ "lo"
#define GCCMACRO__SIZE_FMTu__ "lu"
#define GCCMACRO__SIZE_FMTx__ "lx"
#define GCCMACRO__SIZE_MAX__ 18446744073709551615UL
#define GCCMACRO__SIZE_TYPE__ long unsigned int
#define GCCMACRO__SIZE_WIDTH__ 64
#define GCCMACRO__SSE2_MATH__ 1
#define GCCMACRO__SSE2__ 1
#define GCCMACRO__SSE_MATH__ 1
#define GCCMACRO__SSE__ 1
#define GCCMACRO__STDC_EMBED_EMPTY__ 2
#define GCCMACRO__STDC_EMBED_FOUND__ 1
#define GCCMACRO__STDC_EMBED_NOT_FOUND__ 0
#define GCCMACRO__STDC_HOSTED__ 1
#define GCCMACRO__STDC_UTF_16__ 1
#define GCCMACRO__STDC_UTF_32__ 1
#define GCCMACRO__STDC_VERSION__ 201112L
#define GCCMACRO__STDC__ 1
#define GCCMACRO__SYMBOL_PREFIX 
#define GCCMACRO__UINT16_C(c) c
#define GCCMACRO__UINT16_C_SUFFIX__ 
#define GCCMACRO__UINT16_FMTX__ "hX"
#define GCCMACRO__UINT16_FMTo__ "ho"
#define GCCMACRO__UINT16_FMTu__ "hu"
#define GCCMACRO__UINT16_FMTx__ "hx"
#define GCCMACRO__UINT16_MAX__ 65535
#define GCCMACRO__UINT16_TYPE__ unsigned short
#define GCCMACRO__UINT32_C(c) c##U
#define GCCMACRO__UINT32_C_SUFFIX__ U
#define GCCMACRO__UINT32_FMTX__ "X"
#define GCCMACRO__UINT32_FMTo__ "o"
#define GCCMACRO__UINT32_FMTu__ "u"
#define GCCMACRO__UINT32_FMTx__ "x"
#define GCCMACRO__UINT32_MAX__ 4294967295U
#define GCCMACRO__UINT32_TYPE__ unsigned int
#define GCCMACRO__UINT64_C(c) c##UL
#define GCCMACRO__UINT64_C_SUFFIX__ UL
#define GCCMACRO__UINT64_FMTX__ "lX"
#define GCCMACRO__UINT64_FMTo__ "lo"
#define GCCMACRO__UINT64_FMTu__ "lu"
#define GCCMACRO__UINT64_FMTx__ "lx"
#define GCCMACRO__UINT64_MAX__ 18446744073709551615UL
#define GCCMACRO__UINT64_TYPE__ long unsigned int
#define GCCMACRO__UINT8_C(c) c
#define GCCMACRO__UINT8_C_SUFFIX__ 
#define GCCMACRO__UINT8_FMTX__ "hhX"
#define GCCMACRO__UINT8_FMTo__ "hho"
#define GCCMACRO__UINT8_FMTu__ "hhu"
#define GCCMACRO__UINT8_FMTx__ "hhx"
#define GCCMACRO__UINT8_MAX__ 255
#define GCCMACRO__UINT8_TYPE__ unsigned char
#define GCCMACRO__UINTMAX_C(c) c##UL
#define GCCMACRO__UINTMAX_C_SUFFIX__ UL
#define GCCMACRO__UINTMAX_FMTX__ "lX"
#define GCCMACRO__UINTMAX_FMTo__ "lo"
#define GCCMACRO__UINTMAX_FMTu__ "lu"
#define GCCMACRO__UINTMAX_FMTx__ "lx"
#define GCCMACRO__UINTMAX_MAX__ 18446744073709551615UL
#define GCCMACRO__UINTMAX_TYPE__ long unsigned int
#define GCCMACRO__UINTMAX_WIDTH__ 64
#define GCCMACRO__UINTPTR_FMTX__ "lX"
#define GCCMACRO__UINTPTR_FMTo__ "lo"
#define GCCMACRO__UINTPTR_FMTu__ "lu"
#define GCCMACRO__UINTPTR_FMTx__ "lx"
#define GCCMACRO__UINTPTR_MAX__ 18446744073709551615UL
#define GCCMACRO__UINTPTR_TYPE__ long unsigned int
#define GCCMACRO__UINTPTR_WIDTH__ 64
#define GCCMACRO__UINT_FAST16_FMTX__ "hX"
#define GCCMACRO__UINT_FAST16_FMTo__ "ho"
#define GCCMACRO__UINT_FAST16_FMTu__ "hu"
#define GCCMACRO__UINT_FAST16_FMTx__ "hx"
#define GCCMACRO__UINT_FAST16_MAX__ 65535
#define GCCMACRO__UINT_FAST16_TYPE__ unsigned short
#define GCCMACRO__UINT_FAST32_FMTX__ "X"
#define GCCMACRO__UINT_FAST32_FMTo__ "o"
#define GCCMACRO__UINT_FAST32_FMTu__ "u"
#define GCCMACRO__UINT_FAST32_FMTx__ "x"
#define GCCMACRO__UINT_FAST32_MAX__ 4294967295U
#define GCCMACRO__UINT_FAST32_TYPE__ unsigned int
#define GCCMACRO__UINT_FAST64_FMTX__ "lX"
#define GCCMACRO__UINT_FAST64_FMTo__ "lo"
#define GCCMACRO__UINT_FAST64_FMTu__ "lu"
#define GCCMACRO__UINT_FAST64_FMTx__ "lx"
#define GCCMACRO__UINT_FAST64_MAX__ 18446744073709551615UL
#define GCCMACRO__UINT_FAST64_TYPE__ long unsigned int
#define GCCMACRO__UINT_FAST8_FMTX__ "hhX"
#define GCCMACRO__UINT_FAST8_FMTo__ "hho"
#define GCCMACRO__UINT_FAST8_FMTu__ "hhu"
#define GCCMACRO__UINT_FAST8_FMTx__ "hhx"
#define GCCMACRO__UINT_FAST8_MAX__ 255
#define GCCMACRO__UINT_FAST8_TYPE__ unsigned char
#define GCCMACRO__UINT_LEAST16_FMTX__ "hX"
#define GCCMACRO__UINT_LEAST16_FMTo__ "ho"
#define GCCMACRO__UINT_LEAST16_FMTu__ "hu"
#define GCCMACRO__UINT_LEAST16_FMTx__ "hx"
#define GCCMACRO__UINT_LEAST16_MAX__ 65535
#define GCCMACRO__UINT_LEAST16_TYPE__ unsigned short
#define GCCMACRO__UINT_LEAST32_FMTX__ "X"
#define GCCMACRO__UINT_LEAST32_FMTo__ "o"
#define GCCMACRO__UINT_LEAST32_FMTu__ "u"
#define GCCMACRO__UINT_LEAST32_FMTx__ "x"
#define GCCMACRO__UINT_LEAST32_MAX__ 4294967295U
#define GCCMACRO__UINT_LEAST32_TYPE__ unsigned int
#define GCCMACRO__UINT_LEAST64_FMTX__ "lX"
#define GCCMACRO__UINT_LEAST64_FMTo__ "lo"
#define GCCMACRO__UINT_LEAST64_FMTu__ "lu"
#define GCCMACRO__UINT_LEAST64_FMTx__ "lx"
#define GCCMACRO__UINT_LEAST64_MAX__ 18446744073709551615UL
#define GCCMACRO__UINT_LEAST64_TYPE__ long unsigned int
#define GCCMACRO__UINT_LEAST8_FMTX__ "hhX"
#define GCCMACRO__UINT_LEAST8_FMTo__ "hho"
#define GCCMACRO__UINT_LEAST8_FMTu__ "hhu"
#define GCCMACRO__UINT_LEAST8_FMTx__ "hhx"
#define GCCMACRO__UINT_LEAST8_MAX__ 255
#define GCCMACRO__UINT_LEAST8_TYPE__ unsigned char
#define GCCMACRO__USER_LABEL_PREFIX__ 
#define GCCMACRO__VERSION__ "Clang 23.1.0"
#define GCCMACRO__WCHAR_MAX__ 2147483647
#define GCCMACRO__WCHAR_MIN__ (-__WCHAR_MAX__ - 1)
#define GCCMACRO__WCHAR_TYPE__ int
#define GCCMACRO__WCHAR_WIDTH__ 32
#define GCCMACRO__WINT_MAX__ 4294967295U
#define GCCMACRO__WINT_MIN__ 0U
#define GCCMACRO__WINT_TYPE__ unsigned int
#define GCCMACRO__WINT_UNSIGNED__ 1
#define GCCMACRO__WINT_WIDTH__ 32
#define GCCMACRO__amd64 1
#define GCCMACRO__amd64__ 1
#define GCCMACRO__attribute_copy__(arg) 
#define GCCMACRO__clang__ 1
#define GCCMACRO__clang_literal_encoding__ "UTF-8"
#define GCCMACRO__clang_major__ 23
#define GCCMACRO__clang_minor__ 1
#define GCCMACRO__clang_patchlevel__ 0
#define GCCMACRO__clang_version__ "23.1.0 "
#define GCCMACRO__clang_wide_literal_encoding__ "UTF-32"
#define GCCMACRO__code_model_small__ 1
#define GCCMACRO__gnu_linux__ 1
#define GCCMACRO__hidden_proto(name,thread,internal,attrs...) extern thread __typeof (name) name __hidden_proto_hiddenattr (attrs);
#define GCCMACRO__hidden_proto_alias(name,thread,internal,attrs...) extern thread __typeof (name) internal __hidden_proto_hiddenattr (attrs);
#define GCCMACRO__hidden_proto_hiddenattr(attrs...) __attribute__ ((visibility ("hidden"), ##attrs))
#define GCCMACRO__ifunc(type_name,name,expr,arg,init) __ifunc_args (type_name, name, expr, init, arg)
#define GCCMACRO__ifunc_args(type_name,name,expr,init,...) extern __typeof (type_name) name __attribute__ ((ifunc (#name "_ifunc"))); DIAG_PUSH_NEEDS_COMMENT_CLANG; DIAG_IGNORE_NEEDS_COMMENT_CLANG (13, "-Wunused-function"); __ifunc_resolver (type_name, name, expr, init, static, __VA_ARGS__); DIAG_POP_NEEDS_COMMENT_CLANG;
#define GCCMACRO__ifunc_args_hidden(type_name,name,expr,init,...) __ifunc_args (type_name, name, expr, init, __VA_ARGS__)
#define GCCMACRO__ifunc_hidden(type_name,name,expr,arg,init) __ifunc_args_hidden (type_name, name, expr, init, arg)
#define GCCMACRO__ifunc_resolver(type_name,name,expr,init,classifier,...) classifier __typeof (type_name) *name##_ifunc (__VA_ARGS__) { init (); __typeof (type_name) *res = expr; return res; }
#define GCCMACRO__k8 1
#define GCCMACRO__k8__ 1
#define GCCMACRO__linux 1
#define GCCMACRO__linux__ 1
#define GCCMACRO__llvm__ 1
#define GCCMACRO__make_section_unallocated(section_string) asm (".section " section_string "\n\t.previous");
#define GCCMACRO__pic__ 2
#define GCCMACRO__pie__ 2
#define GCCMACRO__sec_comment "\n\t#"
#define GCCMACRO__seg_fs __attribute__((address_space(257)))
#define GCCMACRO__seg_gs __attribute__((address_space(256)))
#define GCCMACRO__symbol_set_attribute __attribute__ ((weak))
#define GCCMACRO__tune_k8__ 1
#define GCCMACRO__unix 1
#define GCCMACRO__unix__ 1
#define GCCMACRO__x86_64 1
#define GCCMACRO__x86_64__ 1
#define GCCMACRO_elf_set_element(set,symbol) static const void *const __elf_set_##set##_element_##symbol##__ attribute_used_retain __attribute__ ((section (#set))) = &(symbol)
#define GCCMACRO_set_symbol_version(real,name_version) __asm__ (".symver " #real "," name_version)
#define GCCMACRO_strong_alias(name,aliasname) extern __typeof (name) aliasname __attribute__ ((alias (#name))) __attribute_copy__ (name);
#define GCCMACRO_weak_alias(name,aliasname) extern __typeof (name) aliasname __attribute__ ((weak, alias (#name))) __attribute_copy__ (name);
#define GCCMACRO_weak_extern(expr) _Pragma (#expr)
#define GCCMACROattribute_compat_text_section __attribute__ ((section (".text.compat")))
#define GCCMACROattribute_hidden 
#define GCCMACROattribute_relro __attribute__ ((section (".data.rel.ro")))
#define GCCMACROattribute_tls_model_ie __attribute__ ((tls_model ("initial-exec")))
#define GCCMACROattribute_used_retain __attribute__ ((__used__, __retain__))
#define GCCMACRObss_set_element(set,symbol) _elf_set_element(set, symbol)
#define GCCMACROcall_function_static_weak(func,...) ({ extern __typeof__ (func) func weak_function; (func != NULL ? func (__VA_ARGS__) : (void)0); })
#define GCCMACROcc_inhibit_stack_protector __attribute__((no_stack_protector))
#define GCCMACROdata_set_element(set,symbol) _elf_set_element(set, symbol)
#define GCCMACROdeclare_object_symbol_alias(symbol,original,size) declare_object_symbol_alias_1 (symbol, original, size)
#define GCCMACROdeclare_object_symbol_alias_1(symbol,original,size) asm (".global " __SYMBOL_PREFIX # symbol "\n" ".type " __SYMBOL_PREFIX # symbol ", %object\n" ".set " __SYMBOL_PREFIX #symbol ", " __SYMBOL_PREFIX original "\n" ".size " __SYMBOL_PREFIX #symbol ", " #size "\n");
#define GCCMACROdefault_symbol_version(real,name,version) strong_alias(real, name)
#define GCCMACROhidden_data_def(name) 
#define GCCMACROhidden_data_def_alias(name,alias) 
#define GCCMACROhidden_data_weak(name) 
#define GCCMACROhidden_def(name) 
#define GCCMACROhidden_def_alias(name,alias) 
#define GCCMACROhidden_nolink(name,lib,version) 
#define GCCMACROhidden_proto(name,attrs...) __hidden_proto (name, , name, ##attrs)
#define GCCMACROhidden_proto_alias(name,alias,attrs...) __hidden_proto_alias (name, , alias, ##attrs)
#define GCCMACROhidden_tls_def(name) 
#define GCCMACROhidden_tls_proto(name,attrs...) __hidden_proto (name, __thread, name, ##attrs)
#define GCCMACROhidden_ver(local,name) 
#define GCCMACROhidden_weak(name) 
#define GCCMACROignore_value(x) ({ __typeof__ (x) __ignored_value = (x); (void) __ignored_value; })
#define GCCMACROinhibit_loop_to_libcall 
#define GCCMACROinhibit_stack_protector cc_inhibit_stack_protector
#define GCCMACROlibanl_hidden_proto(name,attrs...) 
#define GCCMACROlibc_hidden_builtin_def(name) libc_hidden_def (name)
#define GCCMACROlibc_hidden_builtin_proto(name,attrs...) libc_hidden_proto (name, ##attrs)
#define GCCMACROlibc_hidden_data_def(name) hidden_data_def (name)
#define GCCMACROlibc_hidden_data_def_alias(name,alias) hidden_data_def_alias (name, alias)
#define GCCMACROlibc_hidden_data_weak(name) hidden_data_weak (name)
#define GCCMACROlibc_hidden_def(name) hidden_def (name)
#define GCCMACROlibc_hidden_ldbl_proto(name,attrs...) libc_hidden_proto (name, ##attrs)
#define GCCMACROlibc_hidden_nolink_sunrpc(name,version) hidden_nolink (name, libc, version)
#define GCCMACROlibc_hidden_proto(name,attrs...) hidden_proto (name, ##attrs)
#define GCCMACROlibc_hidden_proto_alias(name,alias,attrs...) hidden_proto_alias (name, alias, ##attrs)
#define GCCMACROlibc_hidden_tls_def(name) hidden_tls_def (name)
#define GCCMACROlibc_hidden_tls_proto(name,attrs...) hidden_tls_proto (name, ##attrs)
#define GCCMACROlibc_hidden_ver(local,name) hidden_ver (local, name)
#define GCCMACROlibc_hidden_weak(name) hidden_weak (name)
#define GCCMACROlibc_ifunc(name,expr) __ifunc (name, name, expr, void, INIT_ARCH)
#define GCCMACROlibc_ifunc_hidden(redirected_name,name,expr) __ifunc_hidden (redirected_name, name, expr, void, INIT_ARCH)
#define GCCMACROlibc_ifunc_redirected(redirected_name,name,expr) __ifunc (redirected_name, name, expr, void, INIT_ARCH)
#define GCCMACROlibm_hidden_def(name) 
#define GCCMACROlibm_hidden_proto(name,attrs...) 
#define GCCMACROlibm_hidden_ver(local,name) 
#define GCCMACROlibm_hidden_weak(name) 
#define GCCMACROlibm_ifunc(name,expr) __ifunc (name, name, expr, void, libm_ifunc_init)
#define GCCMACROlibm_ifunc_init() 
#define GCCMACROlibmvec_hidden_def(name) 
#define GCCMACROlibmvec_hidden_proto(name,attrs...) 
#define GCCMACROlibnsl_hidden_proto(name,attrs...) 
#define GCCMACROlibpthread_hidden_def(name) 
#define GCCMACROlibpthread_hidden_proto(name,attrs...) 
#define GCCMACROlibresolv_hidden_data_def(name) 
#define GCCMACROlibresolv_hidden_def(name) 
#define GCCMACROlibresolv_hidden_proto(name,attrs...) 
#define GCCMACROlibrt_hidden_proto(name,attrs...) 
#define GCCMACROlibrt_hidden_ver(local,name) 
#define GCCMACROlink_warning(symbol,msg) __make_section_unallocated (".gnu.warning." #symbol) static const char __evoke_link_warning_##symbol[] __attribute__ ((used, section (".gnu.warning." #symbol __sec_comment))) = msg;
#define GCCMACROlinux 1
#define GCCMACROrtld_hidden_data_def(name) 
#define GCCMACROrtld_hidden_def(name) 
#define GCCMACROrtld_hidden_proto(name,attrs...) 
#define GCCMACROrtld_hidden_weak(name) 
#define GCCMACROstatic_link_warning(name) static_link_warning1(name)
#define GCCMACROstatic_link_warning1(name) link_warning(name, "Using '" #name "' in statically linked applications requires at runtime the shared libraries from the glibc version used for linking")
#define GCCMACROstatic_weak_alias(name,aliasname) weak_alias (name, aliasname)
#define GCCMACROstrong_alias(name,aliasname) _strong_alias(name, aliasname)
#define GCCMACROstub_warning(name) __make_section_unallocated (".gnu.glibc-stub." #name) link_warning (name, #name " is not implemented and will always fail")
#define GCCMACROsymbol_set_declare(set) extern char const __start_##set[] __symbol_set_attribute; extern char const __stop_##set[] __symbol_set_attribute;
#define GCCMACROsymbol_set_define(set) symbol_set_declare(set)
#define GCCMACROsymbol_set_end_p(set,ptr) ((ptr) >= (void *const *) &__stop_##set)
#define GCCMACROsymbol_set_first_element(set) ((void *const *) (&__start_##set))
#define GCCMACROsymbol_version(real,name,version) 
#define GCCMACROsymbol_version_reference(real,name,version) __asm__ (".symver " #real "," #name "@" #version)
#define GCCMACROtest_cc_inhibit_loop_to_libcall 
#define GCCMACROtext_set_element(set,symbol) _elf_set_element(set, symbol)
#define GCCMACROunix 1
#define GCCMACROweak_alias(name,aliasname) _weak_alias (name, aliasname)
#define GCCMACROweak_const_function __attribute__ ((weak, __const__))
#define GCCMACROweak_extern(symbol) _weak_extern (weak symbol)
#define GCCMACROweak_function __attribute__ ((weak))
