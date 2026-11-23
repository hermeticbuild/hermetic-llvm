"""Checks that --@llvm//config:{opt,dbg,fastbuild}_args replace each mode's flags."""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

_MODES = ["opt", "dbg", "fastbuild"]

def _flag(mode):
    return "//config:%s_args" % mode

def _transition_impl(settings, attr):
    result = {"//command_line_option:compilation_mode": attr.compilation_mode}
    for mode in _MODES:
        args = getattr(attr, mode + "_args")
        result[_flag(mode)] = args if args else settings[_flag(mode)]
    return result

_transition = transition(
    implementation = _transition_impl,
    inputs = [_flag(mode) for mode in _MODES],
    outputs = ["//command_line_option:compilation_mode"] + [_flag(mode) for mode in _MODES],
)

def _check(args, present, absent):
    for flag in present:
        if flag not in args:
            fail("%s is missing: %s" % (flag, args))
    for flag in absent:
        if flag in args:
            fail("%s is present: %s" % (flag, args))

def _contract_impl(ctx):
    toolchain = find_cpp_toolchain(ctx)
    features = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    compile_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_compile,
        variables = cc_common.create_compile_variables(
            cc_toolchain = toolchain,
            feature_configuration = features,
            source_file = "probe.cc",
            output_file = "probe.o",
        ),
    )
    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = features,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = cc_common.create_link_variables(
            cc_toolchain = toolchain,
            feature_configuration = features,
            output_file = "probe",
            is_linking_dynamic_library = False,
        ),
    )
    _check(compile_args, ctx.attr.compile_flags, ctx.attr.no_compile_flags)
    _check(link_args, ctx.attr.link_flags, ctx.attr.no_link_flags)

    report = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(report, json.encode_indent({
        "compilation_mode": ctx.var["COMPILATION_MODE"],
        "compile_args": compile_args,
        "link_args": link_args,
    }) + "\n")
    return [DefaultInfo(files = depset([report]))]

compilation_mode_contract = rule(
    implementation = _contract_impl,
    doc = """Renders the C++ compile and link command lines in `compilation_mode`.

    Analysis fails unless they contain the expected flags. `opt_args`,
    `dbg_args` and `fastbuild_args` set the flags of the same names.
    """,
    attrs = {
        "compilation_mode": attr.string(mandatory = True, values = _MODES),
        "compile_flags": attr.string_list(),
        "dbg_args": attr.label(),
        "fastbuild_args": attr.label(),
        "link_flags": attr.string_list(),
        "no_compile_flags": attr.string_list(),
        "no_link_flags": attr.string_list(),
        "opt_args": attr.label(),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = _transition,
    fragments = ["cpp"],
    toolchains = use_cpp_toolchain(),
)
