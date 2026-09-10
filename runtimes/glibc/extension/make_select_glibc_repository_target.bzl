load("//constraints/libc:libc_versions.bzl", "DEFAULT_LIBC", "GLIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")
load(":glibc.bzl", "glibc_triple")

def declare_glibc_repository_target(name, bazel_repository, bazel_target, **kwargs):
    """Select a target architecture before selecting its glibc version."""
    targets = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        triple = glibc_triple(target_os, target_arch)
        versions = {}
        for libc_version in GLIBCS + ["unconstrained"]:
            apparent_libc_value = libc_version if libc_version != "unconstrained" else DEFAULT_LIBC

            # libc constraint values are "gnu.X.Y"; the glibc repos are keyed
            # by the numeric version only.
            glibc_version = apparent_libc_value.split(".", 1)[1]
            versions["@llvm//constraints/libc:{}".format(libc_version)] = "{}_{}.{}//:{}".format(bazel_repository, triple, glibc_version, bazel_target)

        target_name = "{}_{}_{}".format(name, target_os, target_arch)
        native.alias(
            name = target_name,
            actual = select(versions),
            visibility = ["//visibility:private"],
        )
        targets["@llvm//platforms/config:{}_{}".format(target_os, target_arch)] = target_name

    native.alias(
        name = name,
        actual = select(targets),
        **kwargs
    )
