load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

def _stub_search_directory_name(path):
    if path.endswith("/libcxx_library_search_directory"):
        return "libcxx"
    if path.endswith("/libunwind_library_search_directory"):
        return "libunwind"
    return None

def _append_contract_lines(lines, argument):
    if argument.startswith("-L") and len(argument) > 2:
        stub_search_directory = _stub_search_directory_name(argument[2:])
        if stub_search_directory != None:
            lines.append("search_dir\t%s" % stub_search_directory)
            return

    lines.append("arg\t%s" % argument)

def _linker_contract_from_cc_toolchain_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    link_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = ctx.attr.is_linking_dynamic_library,
        runtime_library_search_directories = [],
        user_link_flags = ctx.attr.user_link_flags,
    )
    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ctx.attr.action_name,
        variables = link_variables,
    )

    lines = [
        "# directive<TAB>payload",
    ]
    pending_search_flag = False
    for argument in link_args:
        if not argument:
            continue
        if pending_search_flag:
            pending_search_flag = False
            stub_search_directory = _stub_search_directory_name(argument)
            if stub_search_directory != None:
                lines.append("search_dir\t%s" % stub_search_directory)
                continue
            lines.append("arg\t-L")
            lines.append("arg\t%s" % argument)
            continue

        if argument == "-L":
            pending_search_flag = True
            continue

        _append_contract_lines(lines, argument)

    if pending_search_flag:
        lines.append("arg\t-L")

    ctx.actions.write(
        output = ctx.outputs.out,
        content = "\n".join(lines) + "\n",
    )

    return [DefaultInfo(files = depset([ctx.outputs.out]))]

linker_contract_from_cc_toolchain = rule(
    doc = "Generates a linker contract by expanding rules_cc link args for one link action.",
    implementation = _linker_contract_from_cc_toolchain_impl,
    attrs = {
        "out": attr.output(
            mandatory = True,
        ),
        "action_name": attr.string(
            default = ACTION_NAMES.cpp_link_executable,
        ),
        "is_linking_dynamic_library": attr.bool(
            default = False,
        ),
        "user_link_flags": attr.string_list(
            default = [],
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
