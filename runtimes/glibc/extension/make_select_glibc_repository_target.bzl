load("//constraints/libc:libc_versions.bzl", "GLIBCS", "UNSUPPORTED_GLIBC_ERROR")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")
load(":glibc.bzl", "glibc_triple")

def declare_glibc_repository_target(name, bazel_repository, bazel_target, **kwargs):
    """Select a target architecture before selecting its glibc version."""
    targets = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        triple = glibc_triple(target_os, target_arch)

        # The glibc repos are keyed by the numeric version only.
        versions = {
            "@llvm//platforms/config:{}".format(glibc): "{}_{}.{}//:{}".format(bazel_repository, triple, glibc.removeprefix("gnu."), bazel_target)
            for glibc in GLIBCS
        }

        target_name = "{}_{}_{}".format(name, target_os, target_arch)
        native.alias(
            name = target_name,
            actual = select(versions, no_match_error = UNSUPPORTED_GLIBC_ERROR),
            visibility = ["//visibility:private"],
        )
        targets["@llvm//platforms/config:{}_{}".format(target_os, target_arch)] = target_name

    native.alias(
        name = name,
        actual = select(targets),
        **kwargs
    )
