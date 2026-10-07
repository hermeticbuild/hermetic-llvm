"""Compare the configured compiler's search paths with a plain driver call."""

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

# These probes also execute on Linux remote workers from Windows hosts.
# Select the hermetic launcher on the executable itself: exec transitions
# must not introduce a host Python dependency. .bazelrc disables host zip defaults.
HEADER_PROBE_PYTHON_SETTINGS = {
    Label("@rules_python//python/config_settings:bootstrap_impl"): "script",
}

def _header_search_impl(ctx):
    toolchain = find_cc_toolchain(ctx)
    features = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = toolchain,
        requested_features = ctx.features + ["system_include_paths"],
        unsupported_features = ctx.disabled_features,
    )
    commands = {}
    for language, action in [("c", ACTION_NAMES.c_compile), ("c++", ACTION_NAMES.cpp_compile)]:
        variables = cc_common.create_compile_variables(
            cc_toolchain = toolchain,
            feature_configuration = features,
            system_include_directories = depset([ctx.file.user_header.dirname]),
        )
        commands[language] = {
            "compiler": cc_common.get_tool_for_action(feature_configuration = features, action_name = action),
            "arguments": cc_common.get_memory_inefficient_command_line(
                feature_configuration = features,
                action_name = action,
                variables = variables,
            ),
        }
    config = ctx.actions.declare_file(ctx.label.name + ".json")
    report = ctx.actions.declare_file(ctx.label.name + ".report.json")
    ctx.actions.write(config, json.encode({
        "family": ctx.attr.family,
        "user": ctx.file.user_header.dirname,
        "commands": commands,
        "link_arguments": cc_common.get_memory_inefficient_command_line(
            feature_configuration = features,
            action_name = ACTION_NAMES.cpp_link_executable,
            variables = cc_common.create_link_variables(
                cc_toolchain = toolchain,
                feature_configuration = features,
                is_using_linker = True,
            ),
        ),
    }))
    ctx.actions.run(
        executable = ctx.executable._checker,
        arguments = [config.path, report.path],
        inputs = depset([config, ctx.file.user_header], transitive = [toolchain.all_files]),
        outputs = [report],
        mnemonic = "ClangHeaderSearch",
        progress_message = "Comparing Clang driver header search for %{label}",
    )
    return DefaultInfo(files = depset([report]))

header_search = rule(
    implementation = _header_search_impl,
    attrs = {
        "family": attr.string(mandatory = True),
        "user_header": attr.label(allow_single_file = True, mandatory = True),
        "_checker": attr.label(default = "//:header_search_checker", executable = True, cfg = "exec"),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
