"""The C++ standard library headers of a macOS SDK sysroot."""

def macos_sdk_libcxx_headers():
    """Declares the libc++ headers of a macOS SDK sysroot as filegroups.

    The split into public and textual headers allows compiling the former
    into a Clang module, see @llvm//toolchain/cc_runtimes:libcxx.
    """

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
