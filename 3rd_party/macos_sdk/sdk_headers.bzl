"""Enumerated headers of a macOS SDK sysroot."""

load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")

def macos_sdk_headers(*, sysroot_directory, framework_globs, excludes = []):
    """Declares the headers of a macOS SDK sysroot as enumerated files.

    The toolchain's module map declares them as `textual header`s: since
    explicit entries win over the sysroot umbrella submodule, these headers
    stay textual even in `-fmodules` builds, where umbrella-owned headers
    could only be included via a compiled module.

    Args:
        sysroot_directory: The sysroot as a target providing DirectoryInfo.
        framework_globs: Glob patterns matching the framework headers of the
            sysroot, relative to the package.
        excludes: Glob patterns excluded from the sysroot.
    """

    # The C and C++ standard library headers.
    subdirectory(
        name = "c_headers",
        parent = sysroot_directory,
        path = "usr/include",
        visibility = ["//visibility:public"],
    )

    # The framework headers. Each framework's Headers directory is a symlink
    # into Versions/, so exclude the latter to list every header once.
    directory(
        name = "framework_headers",
        srcs = native.glob(
            framework_globs,
            exclude = ["**/Versions/**"] + excludes,
            allow_empty = True,
        ),
        visibility = ["//visibility:public"],
    )
