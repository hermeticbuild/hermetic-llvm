"""The C++ standard library headers of a macOS SDK sysroot."""

load("//runtimes/cxxstdlib:libcxx_headers.bzl", "split_libcxx_headers")

def macos_sdk_libcxx_headers():
    """Declares public and textual libc++ header groups from the SDK."""

    headers = native.glob(
        ["usr/include/c++/v1/**"],
        allow_empty = True,
        exclude = ["usr/include/c++/v1/*.modulemap"],
    )
    public_headers, textual_headers = split_libcxx_headers(headers, "usr/include/c++/v1/")

    # Compile public headers such as <vector> into the libc++ module.
    native.filegroup(
        name = "libcxx_public_headers",
        srcs = public_headers,
        visibility = ["//visibility:public"],
    )

    # Keep implementation headers and C wrappers textual.
    native.filegroup(
        name = "libcxx_textual_headers",
        srcs = textual_headers,
        visibility = ["//visibility:public"],
    )
