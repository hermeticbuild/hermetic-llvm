"""Compare the toolchain's link under each runtime setting with its default link."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@with_cfg.bzl", "with_cfg")

_RTLIB = Label("//config:rtlib")
_UNWINDLIB = Label("//config:unwindlib")

_SETTINGS = {
    "_rtlib": attr.label(default = _RTLIB),
    "_unwindlib": attr.label(default = _UNWINDLIB),
}

def _settings(ctx):
    return (
        ctx.attr._rtlib[BuildSettingInfo].value,
        ctx.attr._unwindlib[BuildSettingInfo].value,
    )

def _scope_probe_impl(ctx):
    if _settings(ctx) != ("compiler-rt", "libunwind"):
        fail("target runtime library selection leaked into an exec configuration")
    return [DefaultInfo()]

scope_probe = rule(implementation = _scope_probe_impl, attrs = _SETTINGS)

_ToolchainLinkInfo = provider(
    doc = "Toolchain arguments and runtime libraries, without output directories.",
    fields = ["compile_args", "link_args", "static_runtime", "dynamic_runtime"],
)

def _without_output_dir(value):
    # The settings change the output directories of the target and of the
    # runtime libraries built for it, not the files below them.
    pieces = value.split("bazel-out/")
    result = pieces[0]
    for piece in pieces[1:]:
        end = piece.find("/bin/")
        result += "<bin>" + piece[end + len("/bin"):] if end >= 0 else "bazel-out/" + piece
    return result

def _without_output_dirs(values):
    return [_without_output_dir(value) for value in values]

def _toolchain_link_impl(ctx):
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
    static_runtime = toolchain.static_runtime_lib(feature_configuration = features).to_list()
    dynamic_runtime = toolchain.dynamic_runtime_lib(feature_configuration = features).to_list()
    return [_ToolchainLinkInfo(
        compile_args = _without_output_dirs(compile_args),
        link_args = _without_output_dirs(link_args),
        static_runtime = _without_output_dirs([f.path for f in static_runtime]),
        dynamic_runtime = _without_output_dirs([f.path for f in dynamic_runtime]),
    )]

toolchain_link = rule(
    implementation = _toolchain_link_impl,
    fragments = ["cpp"],
    toolchains = use_cpp_toolchain(),
)

def _defaults_transition_impl(_settings, _attr):
    return {
        str(_RTLIB): "compiler-rt",
        str(_UNWINDLIB): "libunwind",
    }

_defaults_transition = transition(
    implementation = _defaults_transition_impl,
    inputs = [],
    outputs = [str(_RTLIB), str(_UNWINDLIB)],
)

def _is_unwinder(path):
    return path.split("/")[-1].startswith("libunwind.")

def _is_unwinder_stub_directory(arg):
    return arg.startswith("-L") and arg.endswith("/libunwind_library_search_directory")

def _replace_once(args, old, new):
    if len([arg for arg in args if arg == old]) != 1:
        fail("the default link should pass %s once: %s" % (old, args))
    return [new if arg == old else arg for arg in args]

def _runtime_contract_impl(ctx):
    rtlib, unwindlib = _settings(ctx)
    selected = ctx.attr._selected[_ToolchainLinkInfo]
    default = ctx.attr._default[0][_ToolchainLinkInfo]

    link_args = default.link_args
    static_runtime = default.static_runtime
    dynamic_runtime = default.dynamic_runtime

    # Other target OSes ignore both settings.
    if ctx.target_platform_has_constraint(ctx.attr._linux[platform_common.ConstraintValueInfo]):
        if not any([_is_unwinder(path) for path in static_runtime]) or not any([_is_unwinder(path) for path in dynamic_runtime]):
            fail("the default Linux runtime libraries should include libunwind")
        if not any([_is_unwinder_stub_directory(arg) for arg in link_args]):
            fail("the default Linux link should search the libunwind stubs: %s" % link_args)

        link_args = _replace_once(link_args, "-rtlib=compiler-rt", "-rtlib=" + rtlib)

        # The driver adds an unwinder only for libgcc. The toolchain links its
        # libunwind as a runtime library instead.
        link_args = _replace_once(link_args, "--unwindlib=none", "--unwindlib=" + ("libgcc" if unwindlib == "libgcc" else "none"))
        if unwindlib != "libunwind":
            link_args = [arg for arg in link_args if not _is_unwinder_stub_directory(arg)]
            static_runtime = [path for path in static_runtime if not _is_unwinder(path)]
            dynamic_runtime = [path for path in dynamic_runtime if not _is_unwinder(path)]

    if selected.compile_args != default.compile_args:
        fail("runtime settings changed compile arguments:\n%s\nexpected:\n%s" % (selected.compile_args, default.compile_args))
    if selected.link_args != link_args:
        fail("unexpected link arguments for rtlib=%s, unwindlib=%s:\n%s\nexpected:\n%s" % (rtlib, unwindlib, selected.link_args, link_args))
    if selected.static_runtime != static_runtime:
        fail("unexpected static runtime libraries: %s, expected: %s" % (selected.static_runtime, static_runtime))
    if selected.dynamic_runtime != dynamic_runtime:
        fail("unexpected dynamic runtime libraries: %s, expected: %s" % (selected.dynamic_runtime, dynamic_runtime))

    report = ctx.actions.declare_file(ctx.label.name + ".json")
    ctx.actions.write(report, json.encode_indent({
        "dynamic_runtime": selected.dynamic_runtime,
        "link_args": selected.link_args,
        "rtlib": rtlib,
        "static_runtime": selected.static_runtime,
        "unwindlib": unwindlib,
    }) + "\n")
    return [DefaultInfo(files = depset([report]))]

runtime_contract = rule(
    implementation = _runtime_contract_impl,
    attrs = dict(_SETTINGS, **{
        "_default": attr.label(default = "toolchain_link", cfg = _defaults_transition),
        "_exec_scope": attr.label(default = "exec_scope", cfg = "exec"),
        "_linux": attr.label(default = "@platforms//os:linux"),
        "_selected": attr.label(default = "toolchain_link"),
    }),
)

rtlib_libgcc_test, _rtlib_libgcc_test_internal = with_cfg(cc_test).set(_RTLIB, "libgcc").build()

unwindlib_libgcc_test, _unwindlib_libgcc_test_internal = with_cfg(cc_test).set(_UNWINDLIB, "libgcc").build()

unwindlib_none_test, _unwindlib_none_test_internal = with_cfg(cc_test).set(_UNWINDLIB, "none").build()
