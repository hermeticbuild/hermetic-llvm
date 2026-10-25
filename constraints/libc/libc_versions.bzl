GLIBC_VERSIONS = [
    "2.28",
    "2.29",
    "2.30",
    "2.31",
    "2.32",
    "2.33",
    "2.34",
    "2.35",
    "2.36",
    "2.37",
    "2.38",
    "2.39",
    "2.40",
    "2.41",
    "2.42",
    "2.43",
    "2.44",
]

GLIBCS = ["gnu.{}".format(glibc) for glibc in GLIBC_VERSIONS]

LIBCS = ["musl"] + GLIBCS

# The musl version that platforms compiling against musl make available, as understood by
# @platforms_contrib//os/linux/libc/musl. Keep in sync with runtimes/musl/extension/musl.bzl.
MUSL_VERSION = "1.2"

DEFAULT_LIBC = "gnu.2.28"

# For select()s on the //platforms/config:gnu.<version> settings, which match none of the versions
# if the target platform only makes older ones available.
UNSUPPORTED_GLIBC_ERROR = (
    "The target platform only makes glibc versions older than {} available, which aren't " +
    "supported. Make a newer glibc version or musl available on the platform."
).format(GLIBC_VERSIONS[0])

# compile-rt from LLVM requires kernel headers >= 5.10 for RISC-V.
# Keep RISC-V on a libc whose default linux UAPI headers satisfy that.
DEFAULT_LIBCS = {
    ("linux", "riscv64"): "gnu.2.33",
}

def default_libc(target_os, target_cpu):
    return DEFAULT_LIBCS.get((target_os, target_cpu), DEFAULT_LIBC)
