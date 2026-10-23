load("//constraints/libc:libc_versions.bzl", "GLIBCS", "UNSUPPORTED_GLIBC_ERROR")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

# Zig uses arm rather than Bazel's armv7.
_ZIG_CPU_OVERRIDES = {
    "armv7": "arm",
}

# Zig target triples only, not LLVM.
def libc_aware_target_triple():
    prefixes = {
        "//platforms/config:{}_{}".format(target_os, target_cpu): "{}-{}-".format(_ZIG_CPU_OVERRIDES.get(target_cpu, target_cpu), target_os)
        for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS
    }
    families = {
        "//platforms/config:gnu": "gnu",
        "//platforms/config:musl": "musl",
    }
    versions = {
        "//platforms/config:" + glibc: glibc.removeprefix("gnu")
        for glibc in GLIBCS
    }
    versions["//platforms/config:musl"] = ""

    # Keep architecture and libc predicates independent instead of matching
    # their full cross-product. ARM's ABI suffix precedes the libc version.
    return select(prefixes) + select(families) + select({
        "//platforms/config:linux_armv7": "eabihf",
        "//conditions:default": "",
    }) + select(versions, no_match_error = UNSUPPORTED_GLIBC_ERROR)
