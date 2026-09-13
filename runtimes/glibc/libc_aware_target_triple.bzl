load("//constraints/libc:libc_versions.bzl", "DEFAULT_LIBC", "LIBCS")
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
    families = {}
    versions = {}
    for libc in LIBCS + ["unconstrained"]:
        suffix = libc if libc != "unconstrained" else DEFAULT_LIBC
        family, _, version = suffix.partition(".")
        constraint = "//constraints/libc:{}".format(libc)
        families[constraint] = family
        versions[constraint] = "." + version if version else ""

    # Keep architecture and libc predicates independent instead of matching
    # their full cross-product. ARM's ABI suffix precedes the libc version.
    return select(prefixes) + select(families) + select({
        "//platforms/config:linux_armv7": "eabihf",
        "//conditions:default": "",
    }) + select(versions)
