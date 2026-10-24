"""Exercise the public header aliases in configured and unconfigured modules."""

load("@bazel_lib//lib:transitions.bzl", "platform_transition_binary", "platform_transition_filegroup")
load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("@kernel_headers//:linux_kernel_version_map.bzl", "LINUX_KERNEL_VERSION_MAP")
load("@llvm//:defs.bzl", "exec_test")
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

def _selected_headers_test_impl(ctx):
    env = unittest.begin(ctx)
    headers = ctx.attr.headers[CcInfo].compilation_context.headers.to_list()
    directory = ctx.attr.directory[DirectoryInfo].path
    asserts.equals(env, [directory], [header.path for header in headers])
    asserts.true(
        env,
        directory.endswith(".{}/include".format(ctx.attr.version)),
        "Expected Linux {} headers, got {}".format(ctx.attr.version, directory),
    )
    return unittest.end(env)

_selected_headers_test = unittest.make(
    _selected_headers_test_impl,
    attrs = {
        "directory": attr.label(default = Label("@kernel_headers//:kernel_headers_directory")),
        "headers": attr.label(default = Label("@kernel_headers//:kernel_headers")),
        "version": attr.string(mandatory = True),
    },
)

def kernel_headers_selection_tests(default_gnu_version, default_musl_version):
    """Test actual aliases and C includes without changing libc constraints.

    Args:
        default_gnu_version: Expected full version with no kernel constraint.
        default_musl_version: Expected full version for unconstrained musl.
    """
    for name, constraints, version in [
        ("gnu", ["@llvm//constraints/libc:gnu.2.28"], default_gnu_version),
        ("musl", ["@llvm//constraints/libc:musl"], default_musl_version),
        ("unconstrained", [], default_gnu_version),
        ("explicit_gnu", ["@llvm//constraints/libc:gnu.2.28", "@llvm//constraints/kernel/linux:5.4"], LINUX_KERNEL_VERSION_MAP["5.4"]),
        ("explicit_musl", ["@llvm//constraints/libc:musl", "@llvm//constraints/kernel/linux:5.4"], LINUX_KERNEL_VERSION_MAP["5.4"]),
    ]:
        platform = name + "_header_platform"
        native.platform(
            name = platform,
            constraint_values = HOST_CONSTRAINTS + constraints,
        )
        _selected_headers_test(
            name = name + "_selection",
            version = version,
            tags = ["manual"],
        )

        # Generated version codes cap the patch number even when the header's
        # KERNEL_VERSION macro predates that clamp. Check the full path above.
        major, minor, patch = version.split(".")
        c_version = ",".join([major, minor, str(min(int(patch), 255))])
        cc_library(
            name = name + "_compile",
            srcs = [Label("//tests/kernel_headers:version_test.c")],
            defines = ["EXPECTED_KERNEL_VERSION=KERNEL_VERSION({})".format(c_version)],
            linkstatic = True,
            tags = ["manual"],
            deps = [Label("@kernel_headers//:kernel_headers")],
        )
        platform_transition_filegroup(
            name = name + "_compile_files",
            srcs = [name + "_compile"],
            target_platform = platform,
        )
        build_test(
            name = name + "_compile_test",
            targets = [name + "_compile_files"],
        )
        binary = name + "_selection_binary"
        platform_transition_binary(
            name = binary,
            testonly = True,
            binary = name + "_selection",
            target_platform = platform,
        )

        # Inspect aliases in the selected platform; run the test on the host.
        exec_test(
            sh_test,
            name = name + "_selection_test",
            srcs = [Label("//tests/kernel_headers:run_binary.sh")],
            args = ["$(rootpath :" + binary + ")"],
            data = [binary],
            target_compatible_with = ["@platforms//os:linux"],
        )
