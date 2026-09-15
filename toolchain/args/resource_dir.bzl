"""Bind complete link resource-dir arguments to a concrete compiler."""

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains/impl:documented_api.bzl", "cc_args_list")
load("//toolchain:resource_directory.bzl", "resource_directory")

def declare_resource_dir(name, resource_dir):
    """Returns a link-only argument group for the compiler's resource dir."""
    resource_directory(
        name = name + "_resource_directory",
        resource_dir = resource_dir,
    )
    cc_args(
        name = name + "_link_resource_dir",
        actions = ["@rules_cc//cc/toolchains/actions:link_actions"],
        # The joined form works with both Clang and clang-cl response files.
        args = ["-resource-dir={resource_dir}"],
        data = [name + "_resource_directory"],
        format = {"resource_dir": name + "_resource_directory"},
    )

    # Stage0 builds runtime libraries consumed by //runtimes:resource_directory
    # (including compiler-rt builtins), so it must not depend on that tree.
    # Later stages share the directory policy across ABIs, independently of
    # whether their rtlib arguments select compiler-rt; see //toolchain/runtimes:rtlib.
    args = name + "_resource_dir"
    cc_args_list(
        name = args,
        args = select({
            "@llvm//toolchain:runtimes_none": [],
            "//conditions:default": [name + "_link_resource_dir"],
        }),
    )
    return args
