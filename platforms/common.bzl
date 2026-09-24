ARCH_ALIASES = {
    "x86_64": ["amd64"],
    "aarch64": ["arm64"],
    "riscv64": [],
    "s390x": [],
    "armv7": [],
}

SUPPORTED_TARGETS = [
    ("macos", "x86_64"),
    ("macos", "aarch64"),
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("linux", "riscv64"),
    ("linux", "s390x"),
    ("linux", "armv7"),
    ("windows", "x86_64"),
    ("windows", "aarch64"),
    ("none", "bpfeb"),
    ("none", "bpfel"),
    ("none", "wasm32"),
    ("none", "wasm64"),
]

SUPPORTED_EXECS = [
    ("macos", "x86_64"),
    ("macos", "aarch64"),
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("windows", "x86_64"),
    ("windows", "aarch64"),
]

# Stage 0 MSVC target toolchains can use every published execution compiler.
# Windows execution selects the existing GNU/MinGW-built LLVM archive; clang-cl
# still emits the explicit MSVC target configured by the target toolchain.
MSVC_TARGET_STAGE0_SUPPORTED_EXECS = SUPPORTED_EXECS

# Source-built bootstrap compilers use the same supported execution platforms
# as their Stage 0 seeds.
MSVC_TARGET_BOOTSTRAP_SUPPORTED_EXECS = SUPPORTED_EXECS

WINDOWS_TARGETS = [target for target in SUPPORTED_TARGETS if target[0] == "windows"]

LIBC_SUPPORTED_TARGETS = [
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("linux", "riscv64"),
    ("linux", "s390x"),
    ("linux", "armv7"),
]
