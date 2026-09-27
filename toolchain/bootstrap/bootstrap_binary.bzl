load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules/directory:providers.bzl", "create_directory_info")
load("//tools:defs.bzl", "TOOLCHAIN_BINARIES")
load(":transition_settings.bzl", "LLVM_TOOLS", "SANITIZER_FLAGS", "disable_sanitizers")

_LLVM_TOOL_FEATURES = [
    "no_exceptions",
    "no_rtti",
    "omit_frame_pointer",
]

def _append_unique(values, extra_values):
    result = list(values)
    for value in extra_values:
        if value not in result:
            result.append(value)
    return result

def _bootstrap_transition_impl(settings, attr):
    fdo_profile = getattr(attr, "fdo_profile", None)
    fdo_instrumented = getattr(attr, "fdo_instrumented", False)
    source_backed = getattr(attr, "source_backed", False) or fdo_profile or fdo_instrumented
    if fdo_profile and fdo_instrumented:
        fail("fdo_profile and fdo_instrumented are mutually exclusive")

    features = settings["//command_line_option:features"]

    if source_backed:
        bootstrap_stage = "stage1_from_source"
    else:
        bootstrap_stage = "stage0_prebuilt_seed"

    transition_settings = {
        # we are compiling final programs, so we want all runtimes.
        "//toolchain:runtime_stage": "complete",
        "//toolchain:bootstrap_stage": bootstrap_stage,
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:features": _append_unique(features, _LLVM_TOOL_FEATURES + ["thin_lto"]) if source_backed else features,
        "//command_line_option:fdo_profile": fdo_profile,
        "@llvm-project//llvm:driver-tools": LLVM_TOOLS,
        # Bootstrap compilers target the CPU, independent of the CUDA architecture.
        "//config:cuda_device_mode": False,
        "//config:nvidia_compute_capability": "unset",
    }

    disable_sanitizers(transition_settings)

    if fdo_instrumented:
        transition_settings["//config:host_profile"] = True

    if attr.platform:
        transition_settings["//command_line_option:platforms"] = str(attr.platform)
    else:
        transition_settings["//command_line_option:platforms"] = settings["//command_line_option:platforms"]

    return transition_settings

bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [
        "//command_line_option:features",
        "//command_line_option:platforms",
    ],
    outputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:fdo_profile",
        "//command_line_option:features",
        "//command_line_option:platforms",
        "//toolchain:runtime_stage",
        "//toolchain:bootstrap_stage",
        "@llvm-project//llvm:driver-tools",
        "//config:cuda_device_mode",
        "//config:nvidia_compute_capability",
    ] + SANITIZER_FLAGS,
)

def _bootstrap_binary_impl(ctx):
    actual = ctx.attr.actual[0][DefaultInfo]
    exe = actual.files_to_run.executable

    output_name = ctx.label.name
    if ctx.target_platform_has_constraint(
        ctx.attr._windows_constraint[platform_common.ConstraintValueInfo],
    ) and not output_name.endswith(".exe"):
        output_name += ".exe"

    out = ctx.actions.declare_file(output_name)

    if ctx.attr.symlink:
        ctx.actions.symlink(
            output = out,
            target_file = exe,
        )
    else:
        copy_file_action(ctx, exe, out)

    return [
        DefaultInfo(
            files = depset([out]),
            executable = out,
            runfiles = ctx.runfiles(files = [exe]).merge(actual.default_runfiles),
        ),
    ]

bootstrap_binary = rule(
    implementation = _bootstrap_binary_impl,
    executable = True,
    attrs = {
        "actual": attr.label(
            cfg = bootstrap_transition,
            allow_single_file = True,
            mandatory = True,
        ),
        "platform": attr.label(
            default = None,
            doc = "If set, build the actual binary for this platform instead of the incoming target platform.",
        ),
        "source_backed": attr.bool(
            default = False,
            doc = "If set, build with the source-built Stage 1 toolchain and ThinLTO even without FDO.",
        ),
        "symlink": attr.bool(
            default = True,
            doc = "If set to False, will copy the tool instead of symlinking",
        ),
        "fdo_profile": attr.label(
            default = None,
            doc = "If set, build the actual binary with this LLVM FDO profile.",
        ),
        "fdo_instrumented": attr.bool(
            default = False,
            doc = "If set, build the actual binary with FDO instrumentation.",
        ),
        "_windows_constraint": attr.label(
            default = Label("@platforms//os:windows"),
            providers = [platform_common.ConstraintValueInfo],
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)

def bootstrap_binaries(**kwargs):
    for tool in ["llvm"] + TOOLCHAIN_BINARIES:
        bootstrap_binary(
            name = tool,
            actual = "@llvm-project//llvm:llvm.stripped",
            visibility = ["//visibility:public"],
            **kwargs
        )

def _bootstrap_directory_impl(ctx):
    copy_to_directory_bin = ctx.toolchains["@bazel_lib//lib:copy_to_directory_toolchain_type"].copy_to_directory_info.bin

    dst = ctx.actions.declare_directory(ctx.attr.destination)

    copy_to_directory_bin_action(
        ctx,
        name = ctx.attr.name,
        copy_to_directory_bin = copy_to_directory_bin,
        dst = dst,
        files = ctx.files.srcs,
        replace_prefixes = ctx.attr.replace_prefixes,
        include_external_repositories = ["**"],
    )

    transitive_files = depset([dst])

    # Generated tree artifacts are opaque during analysis. Describe their
    # known children so skylib's subdirectory rule can expose precise paths
    # while retaining the parent tree as the single action input.
    subdirectories = {
        subdirectory: create_directory_info(
            entries = {},
            human_readable = "{}/{}".format(ctx.label, subdirectory),
            path = paths.join(dst.path, subdirectory),
            transitive_files = transitive_files,
        )
        for subdirectory in ctx.attr.subdirectories
    }

    return [
        DefaultInfo(files = depset([dst])),
        create_directory_info(
            entries = subdirectories,
            human_readable = str(ctx.label),
            path = dst.path,
            transitive_files = transitive_files,
        ),
    ]

bootstrap_directory = rule(
    implementation = _bootstrap_directory_impl,
    attrs = {
        "srcs": attr.label_list(
            cfg = bootstrap_transition,
            mandatory = True,
        ),
        "subdirectories": attr.string_list(
            doc = "Top-level child directories exposed through DirectoryInfo metadata.",
        ),
        "platform": attr.label(
            default = None,
            doc = "If set, collect sources under this platform instead of the incoming target platform.",
        ),
        "replace_prefixes": attr.string_dict(mandatory = True),
        "destination": attr.string(mandatory = True),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
