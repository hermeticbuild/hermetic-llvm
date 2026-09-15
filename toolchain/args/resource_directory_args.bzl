"""Link arguments for an explicitly supplied resource directory."""

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains/impl:documented_api.bzl", "cc_args_list")

def resource_directory_args(name, directory):
    """Declare link-only arguments, excluding the directory dependency at stage0.

    Args:
        name: Name of the stage-gated argument group.
        directory: Label of an already assembled resource directory.
    """
    cc_args(
        name = name + "_link",
        actions = ["@rules_cc//cc/toolchains/actions:link_actions"],
        # The joined form works with both Clang and clang-cl response files.
        args = ["-resource-dir={directory}"],
        data = [directory],
        format = {"directory": directory},
    )

    # Stage0 builds runtime libraries consumed by //runtimes:resource_directory
    # (including compiler-rt builtins), so it must not depend on that tree.
    # Later stages share the directory policy across ABIs, independently of
    # whether their rtlib arguments select compiler-rt; see //toolchain/runtimes:rtlib.
    cc_args_list(
        name = name,
        args = select({
            "@llvm//toolchain:runtimes_none": [],
            "//conditions:default": [name + "_link"],
        }),
    )
