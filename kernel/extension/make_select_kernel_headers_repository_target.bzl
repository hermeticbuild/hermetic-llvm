load("//constraints/kernel:linux_uapi_versions.bzl", "LINUX_UAPI_VERSIONS")
load("//constraints/libc:libc_versions.bzl", "LIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")
load(":kernel_helpers.bzl", "arch_to_kernel_arch")
load(":libc_kernel_versions.bzl", "LIBC_KERNEL_VERSIONS")

def _kernel_headers_repository_target(target_arch, kernel_version, bazel_target):
    return "@linux_kernel_headers_{}.{}//:{}".format(arch_to_kernel_arch(target_arch), kernel_version, bazel_target)

def _version_alias_name(kernel_version, bazel_target):
    return "linux_uapi_{}_{}".format(kernel_version, bazel_target)

def _fallback_alias_name(bazel_target):
    return "libc_mapped_{}".format(bazel_target)

def _make_select_kernel_headers_repository_target_for_linux_uapi(kernel_version, bazel_target):
    """Select the right kernel headers repository based on the target architecture."""
    selection = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        apparent_target = _kernel_headers_repository_target(target_arch, kernel_version, bazel_target)
        selection["@llvm//platforms/config:{}_{}".format(target_os, target_arch)] = apparent_target

    return select(selection)

def _make_select_kernel_headers_repository_target_from_libc(bazel_target):
    """Select the right kernel headers repository based on the target architecture and libc version."""
    selection = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        for libc_version in LIBCS + ["unconstrained"]:
            kernel_version = LIBC_KERNEL_VERSIONS[libc_version]
            apparent_target = _kernel_headers_repository_target(target_arch, kernel_version, bazel_target)
            selection["@llvm//platforms/config:{}_{}_{}".format(target_os, target_arch, libc_version)] = apparent_target

    return select(selection)

def _make_select_kernel_headers_repository_target_from_linux_uapi(bazel_target):
    """Select explicit linux UAPI constraints, falling back to the libc-derived default."""
    selection = {
        "@llvm//constraints/kernel:linux_uapi_{}".format(kernel_version): ":{}".format(_version_alias_name(kernel_version, bazel_target))
        for kernel_version in LINUX_UAPI_VERSIONS
    }
    selection["@llvm//constraints/kernel:linux_uapi_unconstrained"] = ":{}".format(_fallback_alias_name(bazel_target))

    return select(selection)

def declare_kernel_headers_repository_target(name, bazel_target = None, **kwargs):
    """Declare a kernel headers alias that honors explicit linux UAPI constraints.

    Args:
        name: The public alias name to declare.
        bazel_target: The target within the kernel headers repository to select. Defaults to name.
        **kwargs: Extra keyword arguments to forward to the public alias.
    """
    if bazel_target == None:
        bazel_target = name

    native.alias(
        name = _fallback_alias_name(name),
        actual = _make_select_kernel_headers_repository_target_from_libc(bazel_target),
    )

    for kernel_version in LINUX_UAPI_VERSIONS:
        native.alias(
            name = _version_alias_name(kernel_version, name),
            actual = _make_select_kernel_headers_repository_target_for_linux_uapi(kernel_version, bazel_target),
        )

    native.alias(
        name = name,
        actual = _make_select_kernel_headers_repository_target_from_linux_uapi(name),
        **kwargs
    )
