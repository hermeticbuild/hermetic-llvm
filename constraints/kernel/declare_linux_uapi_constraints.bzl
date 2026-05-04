load(":linux_uapi_versions.bzl", "LINUX_UAPI_VERSIONS")

def declare_linux_uapi_constraints():
    for version in LINUX_UAPI_VERSIONS:
        native.constraint_value(
            name = "linux_uapi_{}".format(version),
            constraint_setting = "version",
        )
