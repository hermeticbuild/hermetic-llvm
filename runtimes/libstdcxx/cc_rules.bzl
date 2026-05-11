load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@with_cfg.bzl", "with_cfg")

def _declare_static_library(*, name, actions):
    basename = paths.basename(name)
    new_basename = "lib{}.a".format(basename)
    return actions.declare_file(name.removesuffix(basename) + new_basename)

def _collect_linker_inputs(deps):
    transitive_linker_inputs = [dep[CcInfo].linking_context.linker_inputs for dep in deps]
    return depset(transitive = transitive_linker_inputs, order = "topological")

def _flatten_and_get_objects(linker_inputs):
    transitive_objects = []
    for linker_input in linker_inputs.to_list():
        for lib in linker_input.libraries:
            if lib._contains_objects:
                transitive_objects.append(depset(lib.pic_objects))
                transitive_objects.append(depset(lib.objects))

    return depset(transitive = transitive_objects, order = "topological")

def _archive_objects(*, name, actions, cc_toolchain, feature_configuration, objects):
    static_library = _declare_static_library(
        name = name,
        actions = actions,
    )

    archiver_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_static_library,
    )
    archiver_variables = cc_common.create_link_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        output_file = static_library.path,
        is_using_linker = False,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_static_library,
        variables = archiver_variables,
    )
    args = actions.args()
    args.add_all(command_line)
    args.add_all(objects)

    if cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = "archive_param_file",
    ):
        args.use_param_file("@%s", use_always = True)

    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_static_library,
        variables = archiver_variables,
    )
    execution_requirements_keys = cc_common.get_execution_requirements(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_static_library,
    )

    actions.run(
        executable = archiver_path,
        arguments = [args],
        env = env,
        execution_requirements = {k: "" for k in execution_requirements_keys},
        inputs = depset(transitive = [cc_toolchain.all_files, objects]),
        outputs = [static_library],
        use_default_shell_env = True,
        mnemonic = "CppTransitiveArchive",
        progress_message = "Creating static library %{output}",
    )

    return static_library

def _cc_static_library_no_validate_impl(ctx):
    # TODO(corentin): remove this once the static library validator accepts the
    # expected COFF C++ COMDAT/refptr duplicates emitted by MinGW libsupc++.
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    linker_inputs = _collect_linker_inputs(ctx.attr.deps)
    static_library = _archive_objects(
        name = ctx.label.name,
        actions = ctx.actions,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        objects = _flatten_and_get_objects(linker_inputs),
    )
    runfiles = ctx.runfiles().merge_all([
        dep[DefaultInfo].default_runfiles
        for dep in ctx.attr.deps
    ])

    return DefaultInfo(
        files = depset([static_library]),
        runfiles = runfiles,
    )

_cc_static_library_no_validate = rule(
    implementation = _cc_static_library_no_validate_impl,
    attrs = {
        "deps": attr.label_list(providers = [CcInfo]),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _configure_libstdcxx_runtime_builder(builder):
    builder.set("copt", [])
    builder.set("cxxopt", [])
    builder.set("linkopt", [])
    builder.set("host_copt", [])
    builder.set("host_cxxopt", [])
    builder.set("host_linkopt", [])

    builder.set(Label("//toolchain:cxxstdlib_mode"), "disabled")

    for sanitizer in [
        "//config:ubsan",
        "//config:cfi",
        "//config:msan",
        "//config:dfsan",
        "//config:nsan",
        "//config:safestack",
        "//config:rtsan",
        "//config:tysan",
        "//config:tsan",
        "//config:asan",
        "//config:lsan",
        "//config:xray",
        "//config:fuzzer",
        "//config:profile",
        "//config:host_ubsan",
        "//config:host_cfi",
        "//config:host_msan",
        "//config:host_dfsan",
        "//config:host_nsan",
        "//config:host_safestack",
        "//config:host_rtsan",
        "//config:host_tysan",
        "//config:host_tsan",
        "//config:host_asan",
        "//config:host_lsan",
        "//config:host_xray",
        "//config:host_fuzzer",
        "//config:host_profile",
    ]:
        builder.set(Label(sanitizer), False)

    return builder

_library_builder = _configure_libstdcxx_runtime_builder(with_cfg(cc_library))
libstdcxx_runtime_cc_library, _libstdcxx_runtime_cc_library_internal = _library_builder.build()

_static_library_builder = _configure_libstdcxx_runtime_builder(with_cfg(cc_static_library))
libstdcxx_runtime_cc_static_library, _libstdcxx_runtime_cc_static_library_internal = _static_library_builder.build()

_static_library_no_validate_builder = _configure_libstdcxx_runtime_builder(with_cfg(_cc_static_library_no_validate))
libstdcxx_runtime_cc_static_library_no_validate, _libstdcxx_runtime_cc_static_library_no_validate_internal = _static_library_no_validate_builder.build()

_binary_builder = _configure_libstdcxx_runtime_builder(with_cfg(cc_binary))
libstdcxx_runtime_cc_binary, _libstdcxx_runtime_cc_binary_internal = _binary_builder.build()
