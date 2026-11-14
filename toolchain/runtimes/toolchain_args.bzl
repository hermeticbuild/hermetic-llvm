"""Ordered toolchain arguments for one runtime stage."""

load("@rules_cc//cc/toolchains/impl:documented_api.bzl", "cc_args_list")
load("//toolchain:stage_independent.bzl", "stage_independent_args_list")

_SANITIZER_FLAGS = [
    "//toolchain/runtimes/args:ubsan_flags",
    "//toolchain/runtimes/args:cfi_flags",
    "//toolchain/runtimes/args:msan_flags",
    "//toolchain/runtimes/args:dfsan_flags",
    "//toolchain/runtimes/args:nsan_flags",
    "//toolchain/runtimes/args:safestack_flags",
    "//toolchain/runtimes/args:rtsan_flags",
    "//toolchain/runtimes/args:tysan_flags",
    "//toolchain/runtimes/args:tsan_flags",
    "//toolchain/runtimes/args:asan_flags",
    "//toolchain/runtimes/args:lsan_flags",
    "//toolchain/runtimes/args:profile_flags",
]

def runtime_toolchain_args(name, stage):
    """Declares the runtime toolchain arguments for `stage` without selecting on it.

    Args:
        name: Name of the stage_independent_args_list target to declare.
        stage: One of "stage0", "stage1" or "stage1_hosted".
    """
    if stage not in ["stage0", "stage1", "stage1_hosted"]:
        fail("Unsupported runtime stage: " + stage)

    hosted = stage == "stage1_hosted"

    # Stage0 builds the CRTs, builtins and libc that later stages link.
    links_runtimes = stage != "stage0"

    cc_args_list(
        name = name + "_hermetic_link_flags",
        args = select({
            # The generic -nostdlib++ policy says that Bazel's runtime attributes
            # own C++ runtime linkage. /NODEFAULTLIB is not its clang-cl equivalent:
            # it would also suppress the selected Microsoft CRT and SDK libraries.
            # The complete MSVC toolchain instead disables libc++ object auto-link
            # metadata and names static libc++ through its default-libraries
            # composition.
            "//constraints/windows/abi:msvc": [],
            "@platforms//os:macos": [],
            "//conditions:default": [
                "//toolchain/runtimes/args:nostdlibxx" if links_runtimes else "//toolchain/runtimes/args:nostdlib",
            ],
        }),
    )

    # Use compiler-rt for intermediate links on every ABI: Microsoft's CRT does
    # not provide every compiler-generated helper (e.g. __udivti3). Stage0 builds
    # these libraries; complete toolchains add //toolchain:rtlib directly through
    # //toolchain:toolchain_args instead.
    rtlib = ["//toolchain:rtlib"] if links_runtimes else []

    # Needs to stay out of resource_dir since clang does not always search for crtstuff for all targets.
    startfiles_and_libs = [
        "//toolchain:default_startfiles",
        "//toolchain:default_libs",
    ] if links_runtimes else []

    cc_args_list(
        name = name + "_generic",
        args = [
            # Common default compile flags.
            "//toolchain/args:target_flags",
            "//toolchain/args:no_absolute_paths_for_builtins",
            "//toolchain/args:deterministic_compile_flags",
            "//toolchain/args:module_map",
            "//toolchain/runtimes/args:optimization_flags",
            "//toolchain:sysroot_flags",
            "//toolchain:hermetic_compile_flags",
            name + "_hermetic_link_flags",

            # Keep external -isystem directories before the toolchain C headers.
            "@rules_cc//cc/toolchains/args/external_include_paths:external_include_paths",

            # TODO(cerisier): Explode this into specific args instead
            ":stage1_hosted_platform_specific_args" if hosted else ":platform_specific_args",
            # Runtime compilation explicitly selects its thread and target feature
            # policy. Complete applications continue to rely on the target triple.
            "//toolchain:thread_model",
            "//toolchain:target_features",
        ] + _SANITIZER_FLAGS + [
            # Common default link flags.
            "//toolchain:deterministic_link_flags",
            ":linker",
            "//toolchain/args:lto_plugin_target_flags",
        ] + rtlib + [
            ":default_link_flags",
        ] + startfiles_and_libs + [
            # TODO: rules_cc passes extra args to these actions, ideally these would be fixed in rules_cc.
            "//toolchain/args:ignore_unused_command_line_argument",
        ],
    )

    windows_headers = ["//toolchain/args/windows:headers_before_compiler_resource"] if hosted else []

    # Keep the complete Windows runtime composition explicit while its individual
    # compiler-personality, object-format, ABI, and runtime semantics are being
    # normalized. This mirrors the generic arguments instead of appending a bag
    # of Windows-only arguments through the platform specific arguments.
    cc_args_list(
        name = name + "_windows",
        args = [
            # Common default compile flags.
            "//toolchain/args/windows:target_flags",
            "//toolchain/args:no_absolute_paths_for_builtins",
            "//toolchain/args/windows:deterministic_compile_flags",
            "//toolchain/args:module_map",
            "//toolchain/runtimes/args:optimization_flags",
            "//toolchain:sysroot_flags",
            "//toolchain:hermetic_compile_flags",
            name + "_hermetic_link_flags",

            # Keep external system include directories before the toolchain C and
            # C++ system include directories below.
            "//toolchain:windows_external_include_paths",

            # Windows compiler, ABI, CRT, object-format, and C++ runtime semantics.
            "//toolchain/args/windows:crt_compile_defines",
        ] + windows_headers + _SANITIZER_FLAGS + [
            # Common default link flags.
            "//toolchain:deterministic_link_flags",
            ":linker",
            "//toolchain/args:lto_plugin_target_flags",
        ] + rtlib + [
            ":default_link_flags",
        ] + startfiles_and_libs + [
            "//toolchain/args/windows:crt_linkage_args",
            "//toolchain/args/windows:ignore_unused_command_line_argument",
        ],
    )

    cc_args_list(
        name = name + "_for_target",
        args = select({
            "@platforms//os:uefi": ["//toolchain:uefi_toolchain_args"],
            "@platforms//os:windows": [name + "_windows"],
            "//conditions:default": [name + "_generic"],
        }),
    )

    stage_independent_args_list(
        name = name,
        args = [name + "_for_target"],
        visibility = ["//visibility:public"],
    )
