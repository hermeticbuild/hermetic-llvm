"""Rules for generating an LLVM bootstrap FDO profile."""

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/private/rules_impl/fdo:fdo_profile.bzl", "FdoProfileInfo")  # buildifier: disable=bzl-visibility
load(":transition_settings.bzl", "LLVM_TOOLS", "SANITIZER_FLAGS", "disable_sanitizers")

LLVMFDOProfileRawInfo = provider(
    doc = "Raw LLVM profiles produced for one target platform.",
    fields = {
        "profraws": "Depset of raw LLVM profile files.",
    },
)

_COMMON_COMPILE_FLAGS = [
    "-x",
    "c",
    "-O3",
    "-fomit-frame-pointer",
    "-ffunction-sections",
    "-fdata-sections",
]

_HOSTED_COMPILE_FLAGS = [
    "-flto=thin",
    "-pthread",
    "-DZSTD_DISABLE_ASM",
    "-DZSTD_MULTITHREAD",
    "-DZSTD_NOBENCH",
    "-DZSTD_NODICT",
    "-DZSTD_NODECOMPRESS",
    "-DZSTD_NOTRACE",
    "-UZSTD_LEGACY_SUPPORT",
    "-DZSTD_LEGACY_SUPPORT=0",
]

_HOSTED_LINK_FLAGS = [
    "-O3",
    "-flto=thin",
    "-pthread",
]

_FREESTANDING_COMPILE_FLAGS = [
    "-ffreestanding",
    "-fno-builtin",
    "-nostdinc",
]

def _profile_generation_transition_impl(_settings, attr):
    transition_settings = {
        "//command_line_option:fdo_profile": None,
        "//command_line_option:platforms": str(attr.target_platform),
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
        "//command_line_option:fdo_profile",
        "//command_line_option:platforms",
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm-project//llvm:driver-tools",
    ] + SANITIZER_FLAGS,
)

def _c_sources(files):
    return [file for file in files if file.extension == "c"]

def _profile_environment(feature_configuration, action_name, variables, profraw):
    env = dict(cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = variables,
    ))
    env["LLVM_PROFILE_FILE"] = profraw.path
    return env

def _llvm_fdo_profile_workload_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)

    if ctx.attr.workload_kind == "hosted":
        if not ctx.executable.linker:
            fail("The hosted workload requires linker")
        compile_flags = _COMMON_COMPILE_FLAGS + _HOSTED_COMPILE_FLAGS
    else:
        compile_flags = _COMMON_COMPILE_FLAGS + _FREESTANDING_COMPILE_FLAGS

    include_dirs = {}
    for file in ctx.files.srcs:
        include_dirs[file.dirname] = None

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    profraws = []
    objects = []
    for index, source in enumerate(_c_sources(ctx.files.srcs)):
        object_file = ctx.actions.declare_file("{}.{}.o".format(ctx.label.name, index))
        profraw = ctx.actions.declare_file("{}.{}.profraw".format(ctx.label.name, index))
        compile_variables = cc_common.create_compile_variables(
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            include_directories = depset(sorted(include_dirs.keys())),
            output_file = object_file.path,
            source_file = source.path,
            user_compile_flags = compile_flags,
        )

        ctx.actions.run(
            executable = ctx.executable.clangxx,
            arguments = cc_common.get_memory_inefficient_command_line(
                feature_configuration = feature_configuration,
                action_name = ACTION_NAMES.c_compile,
                variables = compile_variables,
            ),
            env = _profile_environment(feature_configuration, ACTION_NAMES.c_compile, compile_variables, profraw),
            inputs = depset(
                [source],
                transitive = [ctx.attr.srcs[DefaultInfo].files],
            ),
            tools = cc_toolchain.all_files,
            outputs = [
                object_file,
                profraw,
            ],
            mnemonic = "LLVMFDOProfileCompile",
            progress_message = "Generating LLVM FDO profile input with %{label}",
            execution_requirements = {"supports-path-mapping": "1"},
            toolchain = CC_TOOLCHAIN_TYPE,
        )

        objects.append(object_file)
        profraws.append(profraw)

    if ctx.attr.workload_kind == "freestanding":
        profraws_depset = depset(profraws)
        return [
            DefaultInfo(files = profraws_depset),
            LLVMFDOProfileRawInfo(profraws = profraws_depset),
        ]

    binary_file = ctx.actions.declare_file(ctx.label.name + ".zstd")
    link_variables = cc_common.create_link_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        output_file = binary_file.path,
        user_link_flags = _HOSTED_LINK_FLAGS,
    )
    link_args = ctx.actions.args()
    link_args.add_all(cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = link_variables,
    ))
    link_args.add_all(objects)

    link_profraw = ctx.actions.declare_file(ctx.label.name + ".link.profraw")
    link_tools = depset(
        [ctx.executable.linker],
        transitive = [
            cc_toolchain.all_files,
        ],
    )
    ctx.actions.run(
        executable = ctx.executable.clangxx,
        arguments = [link_args],
        env = _profile_environment(feature_configuration, ACTION_NAMES.cpp_link_executable, link_variables, link_profraw),
        inputs = objects,
        tools = link_tools,
        outputs = [
            binary_file,
            link_profraw,
        ],
        mnemonic = "LLVMFDOProfileLink",
        progress_message = "Linking LLVM FDO training binary with %{label}",
        execution_requirements = {"supports-path-mapping": "1"},
        toolchain = CC_TOOLCHAIN_TYPE,
    )
    profraws.append(link_profraw)

    profraws_depset = depset(profraws)
    return [
        DefaultInfo(files = profraws_depset),
        LLVMFDOProfileRawInfo(profraws = profraws_depset),
    ]

llvm_fdo_profile_workload = rule(
    implementation = _llvm_fdo_profile_workload_impl,
    attrs = {
        "clangxx": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "Instrumented clang++ driver used to collect the profile.",
        ),
        "linker": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            doc = "Instrumented linker executable used by clangxx for target_platform.",
        ),
        "srcs": attr.label(
            allow_files = [".c", ".h"],
            mandatory = True,
            doc = "Training sources compiled for target_platform.",
        ),
        "target_platform": attr.label(
            mandatory = True,
            doc = "Target platform compiled by this training workload.",
        ),
        "workload_kind": attr.string(
            mandatory = True,
            values = [
                "freestanding",
                "hosted",
            ],
            doc = "Whether this workload compiles only or compiles and links.",
        ),
    },
    cfg = _profile_generation_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _llvm_fdo_profile_data_impl(ctx):
    profdata = ctx.actions.declare_file(ctx.label.name + ".profdata")
    profraws = depset(transitive = [
        profile[LLVMFDOProfileRawInfo].profraws
        for profile in ctx.attr.profiles
    ])

    merge_args = ctx.actions.args()
    merge_args.add("merge")
    merge_args.add("--output")
    merge_args.add(profdata)
    merge_args.add_all(profraws)

    ctx.actions.run(
        executable = ctx.executable.llvm_profdata,
        arguments = [merge_args],
        inputs = profraws,
        tools = [ctx.attr.llvm_profdata[DefaultInfo].files_to_run],
        outputs = [profdata],
        mnemonic = "LLVMFDOProfileMerge",
        progress_message = "Merging LLVM FDO profiles for %{label}",
        execution_requirements = {"supports-path-mapping": "1"},
    )

    return [
        DefaultInfo(files = depset([profdata])),
        FdoProfileInfo(
            artifact = profdata,
            proto_profile_artifact = None,
            memprof_artifact = None,
        ),
    ]

llvm_fdo_profile_data = rule(
    implementation = _llvm_fdo_profile_data_impl,
    attrs = {
        "llvm_profdata": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "Uninstrumented llvm-profdata used to merge raw profiles.",
        ),
        "profiles": attr.label_list(
            mandatory = True,
            providers = [LLVMFDOProfileRawInfo],
            doc = "Target-platform training workloads merged into this profile.",
        ),
    },
)
