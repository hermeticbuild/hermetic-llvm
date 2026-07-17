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

    # The public (includable) C++ standard library headers: the extensionless
    # top-level libc++ headers such as <vector>. These are compiled into a
    # Clang module by @llvm//toolchain/cc_runtimes:libcxx.
    native.filegroup(
        name = "libcxx_public_headers",
        srcs = native.glob(
            ["usr/include/c++/v1/*"],
            allow_empty = True,
            exclude = [
                "usr/include/c++/v1/*.h",
                "usr/include/c++/v1/*.imp",
                "usr/include/c++/v1/*.modulemap",
                "usr/include/c++/v1/*.txt",
                "usr/include/c++/v1/__*",
            ],
        ),
        visibility = ["//visibility:public"],
    )

    # All other C++ standard library headers: implementation details, which
    # include mutually exclusive variants that can't all be compiled into a
    # module, and the C standard library wrappers, which include the C
    # standard library headers via include_next and thus have to be textual.
    native.filegroup(
        name = "libcxx_textual_headers",
        srcs = native.glob(
            [
                "usr/include/c++/v1/*.h",
                "usr/include/c++/v1/__*",
                "usr/include/c++/v1/*/**",
            ],
            allow_empty = True,
            exclude = ["usr/include/c++/v1/*.modulemap"],
        ),
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
