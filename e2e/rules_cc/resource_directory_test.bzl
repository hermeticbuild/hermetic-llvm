"""Compile with the link resource override, in either flag-group order."""

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

def _resource_directory_compile_test_impl(ctx):
    toolchain = find_cc_toolchain(ctx)
    features = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = toolchain,
        unsupported_features = ["layering_check", "module_maps"] + ctx.disabled_features,
    )
    link_flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = cc_common.create_link_variables(
            cc_toolchain = toolchain,
            feature_configuration = features,
            is_using_linker = True,
        ),
    )
    resource_flags = [flag for flag in link_flags if flag.startswith("-resource-dir=")]
    if len(resource_flags) != 1:
        fail("expected one complete link resource override, got %s" % resource_flags)

    outputs = []
    for order in ["compile_first", "link_first"]:
        out = ctx.actions.declare_file(ctx.label.name + "_" + order + ".o")
        variables = cc_common.create_compile_variables(
            cc_toolchain = toolchain,
            feature_configuration = features,
            source_file = ctx.file.src.path,
            output_file = out.path,
            user_compile_flags = ctx.attr.copts,
            use_pic = True,
        )
        compile_flags = cc_common.get_memory_inefficient_command_line(
            feature_configuration = features,
            action_name = ACTION_NAMES.cpp_compile,
            variables = variables,
        )
        forbidden = [flag for flag in compile_flags if "resource-dir" in flag or "nobuiltininc" in flag or "/lib/clang/" in flag]
        if forbidden:
            fail("compile flags must leave builtin insertion to the driver: %s" % forbidden)
        ctx.actions.run(
            executable = cc_common.get_tool_for_action(
                feature_configuration = features,
                action_name = ACTION_NAMES.cpp_compile,
            ),
            arguments = compile_flags + resource_flags if order == "compile_first" else resource_flags + compile_flags,
            env = cc_common.get_environment_variables(
                feature_configuration = features,
                action_name = ACTION_NAMES.cpp_compile,
                variables = variables,
            ),
            inputs = [ctx.file.src],
            tools = toolchain.all_files,
            outputs = [out],
            mnemonic = "ResourceDirectoryCompile",
            toolchain = "@bazel_tools//tools/cpp:toolchain_type",
        )
        outputs.append(out)
    return DefaultInfo(files = depset(outputs))

resource_directory_compile = rule(
    implementation = _resource_directory_compile_test_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "copts": attr.string_list(),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
