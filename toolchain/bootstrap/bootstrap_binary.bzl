load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")
load("//tools:defs.bzl", "TOOLCHAIN_BINARIES")
load(":transition_settings.bzl", "LLVM_TOOLS", "SANITIZER_FLAGS", "disable_sanitizers")

_LLVM_TOOL_COPTS = [
    "-fno-exceptions",
    "-fno-rtti",
    "-fomit-frame-pointer",
]

def _append_unique(values, extra_values):
    result = list(values)
    for value in extra_values:
        if value not in result:
            result.append(value)
    return result

def _is_linux_platform(platforms):
    return any(["linux_" in str(platform) for platform in platforms])

def _bootstrap_transition_impl(settings, attr):
    fdo_profile = getattr(attr, "fdo_profile", None)
    fdo_instrumented = getattr(attr, "fdo_instrumented", False)
    if fdo_profile and fdo_instrumented:
        fail("fdo_profile and fdo_instrumented are mutually exclusive")

    copts = settings["//command_line_option:copt"]
    features = settings["//command_line_option:features"]
    linkopts = settings["//command_line_option:linkopt"]
    is_after_stage1 = getattr(attr, "is_after_stage1", False) or fdo_profile or fdo_instrumented

    if attr.platform:
        platform_setting = str(attr.platform)
        platforms = [platform_setting]
    else:
        platform_setting = settings["//command_line_option:platforms"]
        platforms = platform_setting if type(platform_setting) == "list" else [platform_setting]

    # Linux stage3 binaries are BOLT inputs. Preserve their relocations and
    # debug metadata here; llvm_bolt_binary strips the BOLT-optimized outputs.
    is_linux_stage3 = fdo_profile and _is_linux_platform(platforms)

    if is_after_stage1:
        bootstrap_stage = "stage1_from_source"
    else:
        bootstrap_stage = "stage0_prebuilt_seed"

    transition_settings = {
        # we are compiling final programs, so we want all runtimes.
        "//toolchain:runtime_stage": "complete",
        "//toolchain:bootstrap_stage": bootstrap_stage,
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:copt": _append_unique(copts, _LLVM_TOOL_COPTS) if is_after_stage1 else copts,
        "//command_line_option:features": _append_unique(features, ["thin_lto"]) if is_after_stage1 else features,
        "//command_line_option:fdo_profile": fdo_profile,
        "//command_line_option:linkopt": _append_unique(linkopts, ["-Wl,--emit-relocs"]) if is_linux_stage3 else linkopts,
        "//command_line_option:strip": "never" if is_linux_stage3 else settings["//command_line_option:strip"],
        "@llvm-project//llvm:driver-tools": LLVM_TOOLS,
    }

    disable_sanitizers(transition_settings)

    if fdo_instrumented:
        transition_settings["//config:host_profile"] = True

    transition_settings["//command_line_option:platforms"] = platform_setting

    return transition_settings

bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [
        "//command_line_option:copt",
        "//command_line_option:features",
        "//command_line_option:linkopt",
        "//command_line_option:platforms",
        "//command_line_option:strip",
    ],
    outputs = [
        "//command_line_option:copt",
        "//command_line_option:compilation_mode",
        "//command_line_option:fdo_profile",
        "//command_line_option:features",
        "//command_line_option:linkopt",
        "//command_line_option:platforms",
        "//command_line_option:strip",
        "//toolchain:runtime_stage",
        "//toolchain:bootstrap_stage",
        "@llvm-project//llvm:driver-tools",
    ] + SANITIZER_FLAGS,
)

def _bootstrap_binary_impl(ctx):
    actual = ctx.attr.actual[0][DefaultInfo]
    exe = actual.files_to_run.executable

    out = ctx.actions.declare_file(ctx.label.name)

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
        "is_after_stage1": attr.bool(
            default = False,
            doc = "If set, build the actual binary with the stage1 compiler.",
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)

def bootstrap_binaries(**kwargs):
    for tool in ["llvm"] + TOOLCHAIN_BINARIES:
        bootstrap_binary(
            name = tool,
            actual = "@llvm-project//llvm",
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
        replace_prefixes = {ctx.attr.strip_prefix: ""},
        include_external_repositories = ["**"],
    )

    return DefaultInfo(files = depset([dst]))

bootstrap_directory = rule(
    implementation = _bootstrap_directory_impl,
    attrs = {
        "srcs": attr.label(
            cfg = bootstrap_transition,
            mandatory = True,
        ),
        "platform": attr.label(
            default = None,
            doc = "If set, collect sources under this platform instead of the incoming target platform.",
        ),
        "strip_prefix": attr.string(mandatory = True),
        "destination": attr.string(mandatory = True),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
