"""Build all four policies and assert toolchain args, runtimes, and exec scope."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@with_cfg.bzl", "with_cfg")

_SETTINGS = {
    "_nostdincxx": attr.label(default = "//config:nostdincxx"),
    "_nostdlibxx": attr.label(default = "//config:nostdlibxx"),
}

def _scope_probe_impl(ctx):
    if ctx.attr._nostdincxx[BuildSettingInfo].value or ctx.attr._nostdlibxx[BuildSettingInfo].value:
        fail("target C++ standard-library policy leaked into an exec configuration")
    return [DefaultInfo()]

scope_probe = rule(implementation = _scope_probe_impl, attrs = _SETTINGS)

def _stdlib_contract_impl(ctx):
    no_headers = ctx.attr._nostdincxx[BuildSettingInfo].value
    no_libraries = ctx.attr._nostdlibxx[BuildSettingInfo].value
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
            is_static_linking_mode = True,
        ),
    )
    static_runtime = [f.path for f in toolchain.static_runtime_lib(feature_configuration = features).to_list()]
    dynamic_runtime = [f.path for f in toolchain.dynamic_runtime_lib(feature_configuration = features).to_list()]
    suppressed_headers = "-nostdinc++" in compile_args or "/clang:-nostdinc++" in compile_args
    if suppressed_headers != no_headers:
        fail("header suppression differs from nostdincxx: %s" % compile_args)
    if no_headers and any(["cxx_headers_include_search_directory" in arg or "cxxabi_headers_include_search_directory" in arg for arg in compile_args]):
        fail("default C++ include path remains: %s" % compile_args)

    library_evidence = link_args + static_runtime + dynamic_runtime
    has_stdlib = any(["libc++" in arg or "libstdc++" in arg or arg == "-lc++" for arg in library_evidence])
    if has_stdlib == no_libraries:
        fail("implicit C++ library selection differs from nostdlibxx: %s" % library_evidence)
    if ctx.target_platform_has_constraint(ctx.attr._linux[platform_common.ConstraintValueInfo]):
        if not any(["unwind" in path for path in static_runtime]) or not any(["unwind" in path for path in dynamic_runtime]):
            fail("C++ library suppression removed the Linux unwinder")

    report = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(report, json.encode_indent({
        "nostdincxx": no_headers,
        "nostdlibxx": no_libraries,
        "compile_args": compile_args,
        "link_args": link_args,
        "static_runtime": static_runtime,
        "dynamic_runtime": dynamic_runtime,
    }) + "\n")
    return [DefaultInfo(files = depset([report], transitive = [
        ctx.attr._binary[DefaultInfo].files,
        ctx.attr._exec_binary[DefaultInfo].files,
    ]))]

stdlib_contract = rule(
    implementation = _stdlib_contract_impl,
    attrs = dict(_SETTINGS, **{
        "_binary": attr.label(default = "binary"),
        "_exec_binary": attr.label(default = "binary", cfg = "exec"),
        "_exec_scope": attr.label(default = "exec_scope", cfg = "exec"),
        "_linux": attr.label(default = "@platforms//os:linux"),
    }),
    fragments = ["cpp"],
    toolchains = use_cpp_toolchain(),
)

defaults, _defaults_internal = with_cfg(native.filegroup).set(
    Label("//config:nostdincxx"),
    False,
).set(Label("//config:nostdlibxx"), False).build()

headers_only, _headers_only_internal = with_cfg(native.filegroup).set(
    Label("//config:nostdincxx"),
    True,
).set(Label("//config:nostdlibxx"), False).build()

libraries_only, _libraries_only_internal = with_cfg(native.filegroup).set(
    Label("//config:nostdincxx"),
    False,
).set(Label("//config:nostdlibxx"), True).build()

both, _both_internal = with_cfg(native.filegroup).set(
    Label("//config:nostdincxx"),
    True,
).set(Label("//config:nostdlibxx"), True).build()
