"""Source membership and compile options from Cosmopolitan 4.0.2 BUILD.mk."""

_ZLIB_AARCH64_FLAGS = [
    "-DADLER32_SIMD_NEON",
    "-DCRC32_ARMV8_CRC32",
    "-DDEFLATE_SLIDE_HASH_NEON",
    "-DINFLATE_CHUNK_SIMD_NEON",
    "-DINFLATE_CHUNK_READ_64LE",
    "-ffunction-sections",
    "-fdata-sections",
]

_ZLIB_X86_64_FLAGS = [
    "-DADLER32_SIMD_SSSE3",
    "-DCRC32_SIMD_SSE42_PCLMUL",
    "-DCRC32_SIMD_AVX512_PCLMUL",
    "-DDEFLATE_SLIDE_HASH_SSE2",
    "-DINFLATE_CHUNK_SIMD_SSE2",
    "-DINFLATE_CHUNK_READ_64LE",
    "-ffunction-sections",
    "-fdata-sections",
]

_GENERAL_REGS_ONLY_FLAGS = [
    "-D__MGENERAL_REGS_ONLY__",
    "-mgeneral-regs-only",
    "-ffreestanding",
    "-fno-stack-protector",
    "-fno-optimize-sibling-calls",
    "-fwrapv",
]

_LIBUNWIND_FLAGS = [
    "-fexceptions",
    "-ffunction-sections",
    "-fdata-sections",
    "-D_LIBUNWIND_USE_DLADDR=0",
    "-D_LIBUNWIND_IS_BAREMETAL=1",
]

_TINYMATH_FLAGS = [
    "-fmath-errno",
    "-fsigned-zeros",
    "-ftrapping-math",
    "-frounding-math",
    "-fno-reciprocal-math",
    "-fno-associative-math",
    "-fno-finite-math-only",
]

_SHARED_NEXGEN32E_ASM = [
    "libc/nexgen32e/checkstackalign.S",
    "libc/nexgen32e/gc.S",
    "libc/nexgen32e/gclongjmp.S",
    "libc/nexgen32e/kcp437.S",
    "libc/nexgen32e/khalfcache3.S",
    "libc/nexgen32e/ksha256.S",
    "libc/nexgen32e/ksha512.S",
    "libc/nexgen32e/ktensindex.S",
    "libc/nexgen32e/longjmp.S",
    "libc/nexgen32e/mcount.S",
    "libc/nexgen32e/setjmp.S",
    "libc/nexgen32e/zip.S",
]

_X86_64_INTRIN_ASM = [
    "libc/intrin/fds_init.S",
    "libc/intrin/getcpuidbrand.S",
    "libc/intrin/interrupts.S",
    "libc/intrin/kpollnames.S",
    "libc/intrin/leaky.S",
    "libc/intrin/maps_init.S",
    "libc/intrin/pagesize_init.S",
    "libc/intrin/restore.S",
    "libc/intrin/stackchkguard.S",
    "libc/intrin/sys_sched_yield.S",
    "libc/intrin/sys_set_tls.S",
]

_SIZE_OPTIMIZED_SOURCES = [
    "libc/str/getzipcdircomment.c",
    "libc/str/getzipcdircommentsize.c",
    "libc/str/getzipcdiroffset.c",
    "libc/str/getzipcdirrecords.c",
    "libc/str/getzipcfilecompressedsize.c",
    "libc/str/getzipcfilemode.c",
    "libc/str/getzipcfileoffset.c",
    "libc/str/getzipcfiletimestamps.c",
    "libc/str/getzipcfileuncompressedsize.c",
    "libc/str/getzipeocd.c",
    "libc/str/getziplfilecompressedsize.c",
    "libc/str/getziplfileuncompressedsize.c",
    "net/http/categorizeip.c",
    "net/http/gethttpheadername.c",
    "net/http/getipcategoryname.c",
    "net/http/isafrinicip.c",
    "net/http/isanonymousip.c",
    "net/http/isapnicip.c",
    "net/http/isarinip.c",
    "net/http/isdodip.c",
    "net/http/islacnicip.c",
    "net/http/ismulticastip.c",
    "net/http/isripeip.c",
    "net/http/istestnetip.c",
]

def libcosmo_sources():
    return [
        (
            [],
            native.glob([
                "ctl/*.cc",
                "dsp/audio/*.c",
                "libc/calls/*.c",
                "libc/dlopen/*.c",
                "libc/elf/*.c",
                "libc/irq/*.c",
                "libc/log/*.c",
                "libc/nexgen32e/*.c",
                "libc/nt/*.S",
                "libc/nt/API-MS-Win-Core-Realtime-l1-1-1/*.S",
                "libc/nt/API-MS-Win-Core-Synch-l1-2-0/*.S",
                "libc/nt/advapi32/*.S",
                "libc/nt/comdlg32/*.S",
                "libc/nt/gdi32/*.S",
                "libc/nt/iphlpapi/*.S",
                "libc/nt/kernel32/*.S",
                "libc/nt/ntdll/*.S",
                "libc/nt/pdh/*.S",
                "libc/nt/psapi/*.S",
                "libc/nt/shell32/*.S",
                "libc/nt/user32/*.S",
                "libc/nt/ws2_32/*.S",
                "libc/proc/*.c",
                "libc/runtime/*.c",
                "libc/sock/*.S",
                "libc/sock/*.c",
                "libc/stdio/*.c",
                "libc/str/*.c",
                "libc/system/*.c",
                "libc/sysv/*.S",
                "libc/sysv/calls/*.S",
                "libc/sysv/consts/*.S",
                "libc/sysv/dos2errno/*.S",
                "libc/sysv/errfuns/*.S",
                "libc/thread/*.c",
                "libc/x/*.c",
                "net/http/*.c",
                "third_party/compiler_rt/*.c",
                "third_party/compiler_rt/nexgen32e/*.c",
                "third_party/getopt/*.c",
                "third_party/musl/*.c",
                "third_party/regex/*.c",
                "third_party/sed/*.c",
                "third_party/tz/*.c",
                "tool/args/*.c",
            ], exclude = [
                "**/*.greg.c",
                "libc/calls/getloadavg-nt.c",
                "libc/calls/gettimeofday.c",
                "libc/calls/pledge-linux.c",
                "libc/calls/sigaction.c",
                "libc/calls/sigenter-freebsd.c",
                "libc/calls/sigenter-netbsd.c",
                "libc/calls/sigenter-openbsd.c",
                "libc/calls/sigenter-xnu.c",
                "libc/calls/siginfo2cosmo.c",
                "libc/calls/termios2host.c",
                "libc/log/checkfail.c",
                "libc/log/watch.c",
                "libc/runtime/cosmo2.c",
                "libc/runtime/enable_tls.c",
                "libc/stdio/dirstream.c",
                "libc/stdio/fputc.c",
                "libc/stdio/mt19937.c",
                "libc/str/bcmp.c",
                "libc/str/dosdatetimetounix.c",
                "libc/str/iso8601.c",
                "libc/str/iso8601us.c",
                "libc/str/memset16.c",
                "libc/str/wmemset.c",
                "libc/sysv/errfun.S",
                "net/http/formathttpdatetime.c",
                "third_party/tz/localtime.c",
            ] + _SIZE_OPTIMIZED_SOURCES) + [
                "libc/dlopen/foreign_tramp.S",
            ] + _SHARED_NEXGEN32E_ASM + [
                "libc/nt/BCryptPrimitives/ProcessPrng.S",
                "libc/nt/PowrProf/SetSuspendState.S",
                "libc/proc/vfork.S",
                "libc/runtime/clone-linux.S",
                "libc/runtime/ftrace-hook.S",
                "libc/runtime/init.S",
                "libc/runtime/sigsetjmp.S",
                "libc/runtime/zipos.S",
                "libc/vga/readv-vga.c",
                "libc/vga/tty-graph.c",
                "libc/vga/vga-font-default.c",
                "libc/vga/writev-vga.c",
                "third_party/compiler_rt/comprt.S",
            ] + select({
                "@platforms//cpu:x86_64": native.glob([
                    "libc/calls/*.S",
                    "libc/irq/*.S",
                    "libc/log/*.S",
                    "libc/nexgen32e/*.S",
                    "libc/vga/*.S",
                    "third_party/compiler_rt/nexgen32e/*.S",
                ], exclude = _SHARED_NEXGEN32E_ASM) + [
                    "libc/calls/getloadavg-nt.c",
                    "libc/calls/sigaction.c",
                    "libc/runtime/clone-openbsd.S",
                    "libc/runtime/clone-xnu.S",
                    "libc/runtime/cosmo.S",
                    "libc/runtime/efipostboot.S",
                    "libc/runtime/fpreset.S",
                    "libc/runtime/progname.S",
                    "libc/runtime/enable_tls.c",
                    "libc/sysv/errfun.S",
                ],
                "@platforms//cpu:aarch64": [],
            }),
        ),
    ] + _zlib_source_groups() + [
        (
            _GENERAL_REGS_ONLY_FLAGS,
            native.glob(["libc/**/*.greg.c"], exclude = [
                "libc/fmt/itoa64fixed16.greg.c",
                "libc/fmt/itoa64radix16.greg.c",
                "libc/intrin/mman.greg.c",
            ]),
        ),
        (
            _GENERAL_REGS_ONLY_FLAGS + [
                "-O3",
            ],
            [
                "third_party/xed/x86ild.greg.c",
            ],
        ),
        (
            _GENERAL_REGS_ONLY_FLAGS + [
                "-Os",
            ],
            [
                "libc/intrin/mman.greg.c",
            ],
        ),
        (
            _GENERAL_REGS_ONLY_FLAGS + [
                "-fno-jump-tables",
            ],
            [
                "libc/fmt/itoa64fixed16.greg.c",
                "libc/fmt/itoa64radix16.greg.c",
            ],
        ),
        (
            [
                "-O0",
            ],
            [
                "libc/runtime/cosmo2.c",
            ],
        ),
        (
            [
                "-O2",
            ],
            [
                "libc/calls/gettimeofday.c",
                "libc/str/bcmp.c",
            ],
        ),
        (
            [
                "-O2",
                "-ffreestanding",
                "-fno-stack-protector",
            ],
            [
                "libc/intrin/timespectowindowstime.c",
                "libc/intrin/timevaltowindowstime.c",
                "libc/intrin/windowsdurationtotimespec.c",
                "libc/intrin/windowsdurationtotimeval.c",
                "libc/intrin/windowstimetotimespec.c",
                "libc/intrin/windowstimetotimeval.c",
            ],
        ),
        (
            [
                "-O3",
            ],
            [
                "libc/stdio/fputc.c",
                "libc/str/dosdatetimetounix.c",
                "libc/str/iso8601.c",
                "libc/str/iso8601us.c",
                "libc/str/memset16.c",
                "libc/str/wmemset.c",
                "net/http/formathttpdatetime.c",
            ],
        ),
        (
            [
                "-O3",
                "-ffreestanding",
            ],
            [
                "libc/calls/sigenter-freebsd.c",
                "libc/calls/sigenter-netbsd.c",
                "libc/calls/sigenter-openbsd.c",
                "libc/calls/sigenter-xnu.c",
                "libc/calls/siginfo2cosmo.c",
                "libc/calls/termios2host.c",
            ],
        ),
        (
            [
                "-O3",
                "-ffreestanding",
                "-fdata-sections",
                "-ffunction-sections",
            ],
            [
                "third_party/dlmalloc/dlmalloc.c",
            ],
        ),
        (
            [
                "-Os",
            ],
            _SIZE_OPTIMIZED_SOURCES,
        ),
        (
            [
                "-Os",
                "-fPIC",
                "-ffreestanding",
            ],
            [
                "libc/calls/pledge-linux.c",
            ],
        ),
        (
            [
                "-fdata-sections",
                "-ffunction-sections",
            ],
            [
                "third_party/tz/localtime.c",
            ],
        ),
        (
            [
                "-fdata-sections",
                "-ffunction-sections",
                "-fno-strict-aliasing",
            ],
            native.glob([
                "third_party/openmp/*.cpp",
            ]) + [
                "third_party/openmp/util2.S",
            ],
        ),
        (
            [
                "-fexceptions",
            ],
            native.glob([
                "libc/mem/*.c",
            ]),
        ),
        (
            _LIBUNWIND_FLAGS,
            native.glob([
                "third_party/libunwind/*.S",
                "third_party/libunwind/*.c",
            ]),
        ),
        (
            _LIBUNWIND_FLAGS + [
                "-fno-rtti",
            ],
            [
                "third_party/libunwind/libunwind.cc",
            ],
        ),
        (
            [
                "-ffreestanding",
            ],
            native.glob([
                "third_party/xed/*.c",
            ], exclude = [
                "**/*.greg.c",
            ]) + [
                "libc/log/watch.c",
                "third_party/puff/puff.c",
            ] + select({
                "@platforms//cpu:x86_64": [],
                "@platforms//cpu:aarch64": [
                    "libc/calls/getloadavg-nt.c",
                ],
            }),
        ),
        (
            [
                "-ffreestanding",
                "-fdata-sections",
                "-ffunction-sections",
            ],
            native.glob([
                "third_party/nsync/*.c",
                "third_party/nsync/mem/*.c",
            ]) + [
                "third_party/dlmalloc/dlmalloc_abort.c",
                "third_party/dlmalloc/vespene.c",
                "third_party/nsync/compat.S",
            ],
        ),
        (
            [
                "-ffreestanding",
                "-fno-jump-tables",
                "-fpatchable-function-entry=0",
                "-Os",
                "-fno-stack-protector",
            ],
            [
                "libc/intrin/x86.c",
            ],
        ),
        (
            [
                "-ffreestanding",
                "-fno-stack-protector",
            ],
            native.glob([
                "libc/intrin/*.S",
                "libc/intrin/*.c",
            ], exclude = [
                "**/*.greg.c",
            ] + _X86_64_INTRIN_ASM + [
                "libc/intrin/bzero.c",
                "libc/intrin/cursor.c",
                "libc/intrin/memcmp.c",
                "libc/intrin/memmove.c",
                "libc/intrin/mmap.c",
                "libc/intrin/timespectowindowstime.c",
                "libc/intrin/timevaltowindowstime.c",
                "libc/intrin/tree.c",
                "libc/intrin/windowsdurationtotimespec.c",
                "libc/intrin/windowsdurationtotimeval.c",
                "libc/intrin/windowstimetotimespec.c",
                "libc/intrin/windowstimetotimeval.c",
                "libc/intrin/x86.c",
            ]) + select({
                "@platforms//cpu:x86_64": _X86_64_INTRIN_ASM,
                "@platforms//cpu:aarch64": native.glob([
                    "libc/intrin/aarch64/*.S",
                ]),
            }),
        ),
        (
            [
                "-ffreestanding",
                "-fno-stack-protector",
                "-mgeneral-regs-only",
            ],
            native.glob([
                "libc/sysv/*.c",
            ], exclude = [
                "**/*.greg.c",
            ]),
        ),
        (
            [
                "-ffunction-sections",
            ],
            [
                "libc/stdio/dirstream.c",
                "libc/stdio/mt19937.c",
            ],
        ),
        (
            [
                "-ffunction-sections",
                "-fdata-sections",
            ],
            native.glob([
                "third_party/double-conversion/*.cc",
                "third_party/gdtoa/*.c",
            ]) + [
                "third_party/double-conversion/dubble.c",
            ],
        ),
        _libcxx_source_group(),
        (
            [
                "-ffunction-sections",
                "-fdata-sections",
                "-fexceptions",
                "-frtti",
                "-D_LIBCXXABI_BUILDING_LIBRARY",
                "-D_LIBCPP_BUILDING_LIBRARY",
            ],
            native.glob([
                "third_party/libcxxabi/*.cc",
            ]),
        ),
        (
            [
                "-ffunction-sections",
                "-ffreestanding",
                "-fno-stack-protector",
            ],
            [
                "libc/intrin/cursor.c",
                "libc/intrin/mmap.c",
                "libc/intrin/tree.c",
            ],
        ),
        (
            [
                "-ffunction-sections",
            ] + _TINYMATH_FLAGS,
            [
                "libc/tinymath/expl.c",
                "libc/tinymath/loglq.c",
            ],
        ),
        (
            _TINYMATH_FLAGS,
            native.glob([
                "libc/tinymath/*.c",
            ], exclude = [
                "libc/tinymath/expl.c",
                "libc/tinymath/loglq.c",
                "libc/tinymath/lround.c",
                "libc/tinymath/lroundf.c",
                "libc/tinymath/lroundl.c",
            ]),
        ),
        (
            [
                "-fno-builtin",
            ] + _TINYMATH_FLAGS,
            [
                "libc/tinymath/lround.c",
                "libc/tinymath/lroundf.c",
                "libc/tinymath/lroundl.c",
            ],
        ),
        (
            [
                "-fno-jump-tables",
            ],
            native.glob([
                "libc/fmt/*.c",
                "libc/str/*.cc",
            ], exclude = [
                "**/*.greg.c",
                "libc/fmt/atoi.c",
                "libc/fmt/formatint64thousands.c",
                "libc/fmt/wcstol.c",
                "libc/fmt/wcstoul.c",
            ]),
        ),
        (
            [
                "-fno-jump-tables",
                "-O3",
            ],
            [
                "libc/fmt/formatint64thousands.c",
            ],
        ),
        (
            [
                "-fno-jump-tables",
                "-Os",
            ],
            [
                "libc/fmt/atoi.c",
                "libc/fmt/wcstol.c",
                "libc/fmt/wcstoul.c",
            ],
        ),
        (
            [
                "-fpie",
                "-ffreestanding",
                "-fno-stack-protector",
            ],
            [
                "libc/intrin/bzero.c",
                "libc/intrin/memcmp.c",
                "libc/intrin/memmove.c",
            ],
        ),
        (
            [
                "-mcmodel=large",
            ],
            select({
                "@platforms//cpu:x86_64": [],
                "@platforms//cpu:aarch64": [
                    "libc/calls/sigaction.c",
                    "libc/runtime/enable_tls.c",
                ],
            }),
        ),
        (
            [
                "-mgeneral-regs-only",
            ],
            [
                "libc/log/checkfail.c",
            ],
        ),
        (
            [
                "-std=gnu17",
            ],
            native.glob([
                "third_party/tr/*.c",
                "third_party/zlib/gz/*.c",
            ]),
        ),
    ]

def _zlib_source_groups():
    groups = []
    for cpu, flags, variants in [
        ("aarch64", _ZLIB_AARCH64_FLAGS, [
            (
                ["-O3", "-DBUILD_NEON", "-march=armv8-a+aes+crc"],
                ["third_party/zlib/crc32_simd_neon.c", "third_party/zlib/deflate.c"],
            ),
        ]),
        ("x86_64", _ZLIB_X86_64_FLAGS, [
            (
                ["-O3", "-mpclmul", "-mavx512f", "-mvpclmulqdq", "-UCRC32_SIMD_SSE42_PCLMUL", "-DBUILD_AVX512"],
                ["third_party/zlib/crc32_simd_avx512.c"],
            ),
            (
                ["-O3", "-msse4.2", "-mpclmul", "-UCRC32_SIMD_AVX512_PCLMUL", "-DBUILD_SSE42"],
                ["third_party/zlib/crc32_simd_sse42.c", "third_party/zlib/crc_folding.c"],
            ),
            (
                ["-O3", "-mssse3"],
                ["third_party/zlib/adler32_simd.c"],
            ),
        ]),
    ]:
        platform = "@platforms//cpu:" + cpu
        other_platform = "@platforms//cpu:" + ("x86_64" if cpu == "aarch64" else "aarch64")
        for extra_flags, srcs in variants:
            groups.append((flags + extra_flags + ["-std=gnu17"], select({platform: srcs, other_platform: []})))
        excluded = [src for _, srcs in variants for src in srcs]
        groups.append((flags + ["-std=gnu17"], select({
            platform: native.glob(["third_party/zlib/*.c"], exclude = excluded),
            other_platform: [],
        })))
    return groups

def _libcxx_source_group():
    return (
        [
            "-ffunction-sections",
            "-fdata-sections",
            "-fexceptions",
            "-frtti",
            "-DLIBCXX_BUILDING_LIBCXXABI",
            "-D_LIBCPP_BUILDING_LIBRARY",
        ],
        native.glob(["third_party/libcxx/**/*.cpp"]),
    )

def libcxx_sources():
    return [_libcxx_source_group()]

SDK_TOOL_SRCS = {
    "apelink": ["tool/build/lib/parsesupportvector.c"],
    "fixupobj": [],
    "pecheck": [],
    "zipobj": [
        "tool/build/lib/elfwriter.c",
        "tool/build/lib/elfwriter_cargoculting.c",
        "tool/build/lib/elfwriter_yoink.c",
        "tool/build/lib/elfwriter_zip.c",
        "tool/build/lib/interner.c",
        "tool/build/lib/stripcomponents.c",
    ],
}
