load(":linux_kernel_versions.bzl", "LINUX_KERNEL_VERSIONS")

def declare_linux_kernel_constraints():
    for version in LINUX_KERNEL_VERSIONS:
        native.constraint_value(
            name = version,
            constraint_setting = "version",
        )
