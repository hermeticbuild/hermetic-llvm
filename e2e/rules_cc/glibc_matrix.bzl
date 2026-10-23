load("@bazel_lib//lib:transitions.bzl", "platform_transition_filegroup")
load("@llvm//constraints/libc:libc_versions.bzl", "GLIBC_VERSIONS", "glibc_supported")
load("@llvm//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

def glibc_build_matrix():
    """Build complete consumer binaries for every published GNU platform."""
    for _, arch in LIBC_SUPPORTED_TARGETS:
        targets = []
        for version in GLIBC_VERSIONS:
            if not glibc_supported(arch, version):
                continue
            name = "glibc_build_{}_{}".format(arch, version.replace(".", "_"))
            platform_transition_filegroup(
                name = name,
                testonly = True,
                srcs = [
                    "main",
                    "glibc_runtime_pie",
                    "glibc_runtime_nopie",
                ],
                tags = ["manual"],
                target_platform = "@llvm//platforms:linux_{}_gnu.{}".format(arch, version),
            )
            targets.append(name)
        native.filegroup(
            name = "glibc_build_matrix_" + arch,
            testonly = True,
            srcs = targets,
            tags = ["manual"],
        )
