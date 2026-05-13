"""Rules for generating an LLVM bootstrap FDO profile."""

load("@rules_cc//cc:action_names.bzl", "CPP_COMPILE_ACTION_NAME", "CPP_LINK_EXECUTABLE_ACTION_NAME")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":transition_settings.bzl", "FDO_EXECUTION_PLATFORMS", "LLVM_TOOLS", "SANITIZER_FLAGS", "disable_sanitizers")

_TRAINING_COPTS = [
    "-O3",
    "-flto=thin",
    "-fno-exceptions",
    "-fno-rtti",
    "-fomit-frame-pointer",
    "-DZSTD_STATIC_LINKING_ONLY",
]

_TRAINING_LINKOPTS = [
    "-O3",
    "-flto=thin",
    "-fuse-ld=lld",
]

def _profile_generation_transition_impl(settings, attr):
    transition_settings = {
        "//command_line_option:extra_execution_platforms": FDO_EXECUTION_PLATFORMS,
        "//command_line_option:fdo_profile": None,
        "//command_line_option:platforms": str(attr.platform),
        "//toolchain:runtime_stage": "complete",
        "//toolchain:source": "prebuilt",
        "@llvm-project//llvm:driver-tools": LLVM_TOOLS,
    }

    disable_sanitizers(transition_settings)

    return transition_settings

_profile_generation_transition = transition(
    implementation = _profile_generation_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:extra_execution_platforms",
        "//command_line_option:fdo_profile",
        "//command_line_option:platforms",
    ] + SANITIZER_FLAGS + [
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm-project//llvm:driver-tools",
    ],
)

def _merge_compilation_contexts(deps):
    contexts = [
        dep[CcInfo].compilation_context
        for dep in deps
        if CcInfo in dep
    ]
    if not contexts:
        return cc_common.create_compilation_context()
    return cc_common.merge_compilation_contexts(compilation_contexts = contexts)

def _collect_link_inputs(deps):
    libraries = []
    user_link_flags = []

    for dep in deps:
        if CcInfo not in dep:
            continue

        for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
            user_link_flags.extend(_to_list(getattr(linker_input, "user_link_flags", [])))
            for library in _to_list(getattr(linker_input, "libraries", [])):
                library_file = (
                    getattr(library, "pic_static_library", None) or
                    getattr(library, "static_library", None) or
                    getattr(library, "interface_library", None) or
                    getattr(library, "dynamic_library", None)
                )
                if library_file:
                    libraries.append(library_file)

    return libraries, user_link_flags

def _to_list(value):
    return value.to_list() if hasattr(value, "to_list") else list(value)

def _merge_env(*envs):
    merged = {}
    for env in envs:
        merged.update(env)
    return merged

def _llvm_fdo_profile_data_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    compilation_context = _merge_compilation_contexts(ctx.attr.deps)
    libraries, dep_link_flags = _collect_link_inputs(ctx.attr.deps)

    object_file = ctx.actions.declare_file(ctx.label.name + ".zstd.o")
    binary_file = ctx.actions.declare_file(ctx.label.name + ".zstd")
    profdata = ctx.actions.declare_file(ctx.label.name + ".profdata")

    defines = depset(transitive = [
        getattr(compilation_context, "defines", depset()),
        getattr(compilation_context, "local_defines", depset()),
    ])

    compile_variables = cc_common.create_compile_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        source_file = ctx.file.src.path,
        output_file = object_file.path,
        user_compile_flags = ctx.fragments.cpp.copts + _TRAINING_COPTS + ctx.attr.copts,
        include_directories = getattr(compilation_context, "includes", depset()),
        quote_include_directories = getattr(compilation_context, "quote_includes", depset()),
        system_include_directories = getattr(compilation_context, "system_includes", depset()),
        framework_include_directories = getattr(compilation_context, "framework_includes", depset()),
        preprocessor_defines = defines,
        use_pic = True,
    )
    compile_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = compile_variables,
    )
    compile_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = compile_variables,
    )

    link_variables = cc_common.create_link_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        output_file = binary_file.path,
        user_link_flags = dep_link_flags + _TRAINING_LINKOPTS + ctx.attr.linkopts,
        is_using_linker = True,
        is_linking_dynamic_library = False,
    )
    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = link_variables,
    )
    link_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = link_variables,
    )

    args = ctx.actions.args()
    args.add(ctx.executable.clangxx)
    args.add(ctx.executable.llvm_profdata)
    args.add(profdata)
    args.add(binary_file)
    args.add("--compile")
    args.add_all(compile_args)
    args.add("--link")
    args.add_all(link_args)
    args.add(object_file)
    args.add_all(libraries)

    ctx.actions.run(
        executable = ctx.executable._runner,
        arguments = [args],
        env = _merge_env(compile_env, link_env),
        inputs = depset(
            direct = [ctx.file.src] + libraries,
            transitive = [
                cc_toolchain.all_files,
                getattr(compilation_context, "headers", depset()),
            ],
        ),
        tools = [
            ctx.attr.clangxx[DefaultInfo].files_to_run,
            ctx.attr.llvm_profdata[DefaultInfo].files_to_run,
        ] + ctx.files.data,
        outputs = [
            object_file,
            binary_file,
            profdata,
        ],
        mnemonic = "LLVMFDOProfile",
        progress_message = "Generating LLVM FDO profile with %{label}",
        toolchain = CC_TOOLCHAIN_TYPE,
        execution_requirements = {"supports-path-mapping": "1"},
    )

    return [DefaultInfo(files = depset([profdata]))]

llvm_fdo_profile_data = rule(
    implementation = _llvm_fdo_profile_data_impl,
    attrs = {
        "clangxx": attr.label(
            executable = True,
            cfg = "target",
            mandatory = True,
            doc = "Instrumented clang++ driver used to collect the profile.",
        ),
        "copts": attr.string_list(default = []),
        "data": attr.label_list(
            allow_files = True,
            doc = "Files needed next to the instrumented compiler, such as lld and builtin headers.",
        ),
        "deps": attr.label_list(providers = [CcInfo]),
        "linkopts": attr.string_list(default = []),
        "llvm_profdata": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "target",
            mandatory = True,
            doc = "Uninstrumented llvm-profdata used to merge raw profiles.",
        ),
        "platform": attr.label(
            default = Label("//:rbe_platform"),
            doc = "Execution/target platform used for the training binary.",
        ),
        "src": attr.label(
            allow_single_file = [".cc", ".cpp", ".cxx"],
            mandatory = True,
        ),
        "_runner": attr.label(
            default = Label("//toolchain/bootstrap:llvm_fdo_profile_runner"),
            executable = True,
            cfg = "exec",
        ),
    },
    cfg = _profile_generation_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
