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

def _bootstrap_transition_impl(_settings, attr):
    return {
        "//command_line_option:platforms": str(attr.platform),

        # we don't want to pass sanitizers up the compiler toolchain for now
        "//config:ubsan": False,
        "//config:cfi": False,
        "//config:msan": False,
        "//config:dfsan": False,
        "//config:nsan": False,
        "//config:safestack": False,
        "//config:rtsan": False,
        "//config:tysan": False,
        "//config:tsan": False,
        "//config:asan": False,
        "//config:lsan": False,
        "//config:host_ubsan": False,
        "//config:host_cfi": False,
        "//config:host_msan": False,
        "//config:host_dfsan": False,
        "//config:host_nsan": False,
        "//config:host_safestack": False,
        "//config:host_rtsan": False,
        "//config:host_tysan": False,
        "//config:host_tsan": False,
        "//config:host_asan": False,
        "//config:host_lsan": False,

        # we are compiling final programs, so we want all runtimes.
        "//toolchain:runtime_stage": "complete",

        # We want to build those binaries using the prebuilt compiler toolchain
        "//toolchain:source": "prebuilt",
        "@llvm-project//llvm:driver-tools": _LLVM_TOOLS,
    }

bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [],
    outputs = [
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
            mandatory = True,
        ),
        "symlink": attr.bool(
            default = True,
            doc = "If set to False, will copy the tool instead of symlinking",
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)

# TODO(zbarsky): This should replace bootstrap_binary once rules_cc is fixed.
def _exec_bootstrap_transition_impl(_settings, _attr):
    return {
        "//config:ubsan": False,
        "//config:cfi": False,
        "//config:msan": False,
        "//config:dfsan": False,
        "//config:nsan": False,
        "//config:safestack": False,
        "//config:rtsan": False,
        "//config:tysan": False,
        "//config:tsan": False,
        "//config:asan": False,
        "//config:lsan": False,
        "//config:host_ubsan": False,
        "//config:host_cfi": False,
        "//config:host_msan": False,
        "//config:host_dfsan": False,
        "//config:host_nsan": False,
        "//config:host_safestack": False,
        "//config:host_rtsan": False,
        "//config:host_tysan": False,
        "//config:host_tsan": False,
        "//config:host_asan": False,
        "//config:host_lsan": False,

        # we are compiling final programs, so we want all runtimes.
        "//toolchain:runtime_stage": "complete",

        # We want to build those binaries using the prebuilt compiler toolchain
        "//toolchain:source": "prebuilt",

        # Enable the same set of tools we provide with prebuilts.
        "@llvm-project//llvm:driver-tools": _LLVM_TOOLS,
    }

exec_bootstrap_transition = transition(
    implementation = _exec_bootstrap_transition_impl,
    inputs = [],
    outputs = [
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
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm-project//llvm:driver-tools",
    ],
)

# TODO(zbarsky): This should replace bootstrap_binary once rules_cc is fixed.
exec_bootstrap_binary = rule(
    implementation = _bootstrap_binary_impl,
    executable = True,
    attrs = {
        "actual": attr.label(
            cfg = exec_bootstrap_transition,
            allow_single_file = True,
            mandatory = True,
        ),
        "symlink": attr.bool(
            default = True,
            doc = "If set to False, will copy the tool instead of symlinking",
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
            mandatory = True,
        ),
        "strip_prefix": attr.string(mandatory = True),
        "destination": attr.string(mandatory = True),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
