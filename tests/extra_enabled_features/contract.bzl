"""Checks where --@llvm//toolchain:extra_enabled_features puts its flags."""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@with_cfg.bzl", "with_cfg")

EXTRA_COMPILE_FLAG = "-DEXTRA_ENABLED_FEATURE"
EXTRA_LINK_FLAG = "-Lextra_enabled_feature"
_USER_COMPILE_FLAG = "-DUSER_COMPILE_FLAG"
_USER_LINK_FLAG = "-Luser_link_flag"

# Defaults of the toolchain that the extra features must be able to override.
_DEFAULT_COMPILE_FLAGS = ["-std=c++17", "/std:c++17", "-O2", "/O2"]

def _index(args, flag):
    # clang-cl passes user link flags as /clang:<flag>.
    for i, arg in enumerate(args):
        if arg == flag or arg == "/clang:" + flag:
            return i
    fail("%s is missing: %s" % (flag, args))

def _check_order(args, extra_flag, user_flag, default_flags):
    extra = _index(args, extra_flag)
    if extra > _index(args, user_flag):
        fail("%s comes after the user flag %s: %s" % (extra_flag, user_flag, args))
    defaults = [flag for flag in default_flags if flag in args]
    if default_flags and not defaults:
        fail("none of the default flags %s is present: %s" % (default_flags, args))
    for flag in defaults:
        if args.index(flag) > extra:
            fail("%s comes before the default flag %s: %s" % (extra_flag, flag, args))

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
            user_compile_flags = [_USER_COMPILE_FLAG],
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
            user_link_flags = [_USER_LINK_FLAG],
        ),
    )

    if ctx.attr._extra_enabled_features.label == ctx.attr._extra_feature.label:
        _check_order(compile_args, EXTRA_COMPILE_FLAG, _USER_COMPILE_FLAG, _DEFAULT_COMPILE_FLAGS)
        _check_order(link_args, EXTRA_LINK_FLAG, _USER_LINK_FLAG, [])
    elif EXTRA_COMPILE_FLAG in compile_args or EXTRA_LINK_FLAG in link_args:
        fail("the extra features apply without the flag: %s %s" % (compile_args, link_args))

    report = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(report, json.encode_indent({
        "extra_enabled_features": str(ctx.attr._extra_enabled_features.label),
        "compile_args": compile_args,
        "link_args": link_args,
    }) + "\n")
    return [DefaultInfo(files = depset([report]))]

extra_features_contract = rule(
    implementation = _contract_impl,
    attrs = {
        "_extra_enabled_features": attr.label(default = "//toolchain:extra_enabled_features"),
        "_extra_feature": attr.label(default = ":extra_feature"),
    },
    fragments = ["cpp"],
    toolchains = use_cpp_toolchain(),
)

# Both build the contract in opt mode, so that -O2 is among the defaults.
without_extra_features, _without_extra_features_internal = with_cfg(native.filegroup).set(
    "compilation_mode",
    "opt",
).build()

with_extra_features, _with_extra_features_internal = with_cfg(native.filegroup).set(
    "compilation_mode",
    "opt",
).set(
    Label("//toolchain:extra_enabled_features"),
    Label(":extra_feature"),
).build()
