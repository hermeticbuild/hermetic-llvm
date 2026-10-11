"""Arguments for explicitly supplied compile and link resource directories."""

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains/impl:documented_api.bzl", "cc_args_list")

def resource_directory_args(name, compile_directory, link_directory, compile_include_directory = None):
    """Declare compiler-native compile and fully assembled link directories.

    Args:
        name: Name of the stage-gated argument group.
        compile_directory: Resource directory belonging to the selected compiler.
        link_directory: Label of an already assembled resource directory.
        compile_include_directory: Builtin header include directory under compile_directory.
    """
    if compile_include_directory == None:
        compile_include_directory = compile_directory
    cc_args(
        name = name + "_compile",
        actions = ["@rules_cc//cc/toolchains/actions:source_compile_actions"],
        args = select({
            "@llvm//constraints/windows/abi:msvc": [
                "/clang:-nobuiltininc",
                "/imsvc{include_directory}",
            ],
            "//conditions:default": [
                "-Xclang",
                "-internal-isystem",
                "-Xclang",
                "{include_directory}",
            ],
        }),
        data = [compile_directory],
        format = {"include_directory": compile_include_directory},
    )

    cc_args(
        name = name + "_link",
        actions = ["@rules_cc//cc/toolchains/actions:link_actions"],
        # The joined form works with both Clang and clang-cl response files.
        args = ["-resource-dir={directory}"],
        data = [link_directory],
        format = {"directory": link_directory},
    )

    # Stage0 builds runtime libraries consumed by //runtimes:resource_directory
    # (including compiler-rt builtins), so it must not depend on that tree.
    # Later stages share the directory policy across ABIs, independently of
    # whether their rtlib arguments select compiler-rt; see //toolchain/runtimes:rtlib.
    #
    # rules_foreign_cc may combine CFLAGS and LDFLAGS in one driver invocation.
    # Conventional build systems put LDFLAGS last, so Clang selects the complete
    # link directory (Clang resolves repeated -resource-dir options last-wins).
    cc_args_list(
        name = name,
        args = [name + "_compile"] + select({
            "@llvm//toolchain:runtimes_none": [],
            "//conditions:default": [name + "_link"],
        }),
    )
