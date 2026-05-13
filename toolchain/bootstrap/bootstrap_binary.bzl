load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")

# Enable the same set of tools we provide with prebuilts.
_LLVM_TOOLS = [
    "clang",
    "clang-scan-deps",
    "dsymutil",
    "lld",
    "llvm-ar",
    "llvm-cgdata",
    "llvm-cov",
    "llvm-cxxfilt",
    "llvm-debuginfod-find",
    "llvm-dwp",
    "llvm-gsymutil",
    "llvm-ifs",
    "llvm-libtool-darwin",
    "llvm-link",
    "llvm-lipo",
    "llvm-ml",
    "llvm-mt",
    "llvm-nm",
    "llvm-objcopy",
    "llvm-objdump",
    "llvm-profdata",
    "llvm-rc",
    "llvm-readobj",
    "llvm-readtapi",
    "llvm-size",
    "llvm-symbolizer",
    "sancov",
]

_SANITIZER_FLAGS = [
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
]

_LLVM_TOOL_LTO_FLAGS = [
    "-flto=thin",
]

_LLVM_TOOL_COPTS = _LLVM_TOOL_LTO_FLAGS + [
    "-fno-exceptions",
    "-fno-rtti",
    "-fomit-frame-pointer",
]

_LLVM_TOOL_LINKOPTS = _LLVM_TOOL_LTO_FLAGS

_FDO_EXECUTION_PLATFORMS = [
    "@llvm//:rbe_platform",
]

def _append_unique(values, extra_values):
    result = list(values)
    for value in extra_values:
        if value not in result:
            result.append(value)
    return result

def _remove_values(values, removed_values):
    removed = {value: None for value in removed_values}
    return [
        value
        for value in values
        if value not in removed
    ]

def _bootstrap_transition_impl(settings, attr):
    fdo_profile = getattr(attr, "fdo_profile", None)
    profile_instrumented = getattr(attr, "profile_instrumented", False)
    if fdo_profile and profile_instrumented:
        fail("fdo_profile and profile_instrumented are mutually exclusive")

    copts = settings["//command_line_option:copt"]
    linkopts = settings["//command_line_option:linkopt"]
    needs_llvm_optimization = fdo_profile or profile_instrumented
    transition_settings = {
        # we are compiling final programs, so we want all runtimes.
        "//toolchain:runtime_stage": "complete",
        "//toolchain:source": "instrumented" if fdo_profile else "stage1" if profile_instrumented else "prebuilt",
        "//command_line_option:compilation_mode": "opt" if needs_llvm_optimization else settings["//command_line_option:compilation_mode"],
        "//command_line_option:copt": _append_unique(copts, _LLVM_TOOL_COPTS) if needs_llvm_optimization else _remove_values(copts, _LLVM_TOOL_LTO_FLAGS),
        "//command_line_option:linkopt": _append_unique(linkopts, _LLVM_TOOL_LINKOPTS) if needs_llvm_optimization else _remove_values(linkopts, _LLVM_TOOL_LTO_FLAGS),
        "//command_line_option:extra_execution_platforms": settings["//command_line_option:extra_execution_platforms"],
        "//command_line_option:fdo_profile": str(fdo_profile) if fdo_profile else None,
        "@llvm-project//llvm:driver-tools": _LLVM_TOOLS,
    }

    for flag in _SANITIZER_FLAGS:
        transition_settings[flag] = False

    if profile_instrumented:
        transition_settings["//config:profile"] = True
        transition_settings["//command_line_option:compilation_mode"] = "opt"
        transition_settings["//command_line_option:extra_execution_platforms"] = _FDO_EXECUTION_PLATFORMS

    if attr.platform:
        transition_settings["//command_line_option:platforms"] = str(attr.platform)
    else:
        transition_settings["//command_line_option:platforms"] = settings["//command_line_option:platforms"]

    return transition_settings

bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [
        "//command_line_option:copt",
        "//command_line_option:compilation_mode",
        "//command_line_option:extra_execution_platforms",
        "//command_line_option:linkopt",
        "//command_line_option:platforms",
        "//toolchain:source",
    ],
    outputs = [
        "//command_line_option:copt",
        "//command_line_option:compilation_mode",
        "//command_line_option:extra_execution_platforms",
        "//command_line_option:fdo_profile",
        "//command_line_option:linkopt",
        "//command_line_option:platforms",
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
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm-project//llvm:driver-tools",
    ],
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
            runfiles = actual.default_runfiles,
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
        "profile_instrumented": attr.bool(
            default = False,
            doc = "If set, build the actual binary with LLVM profile instrumentation.",
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
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
