load("//platforms:common.bzl", "CUDA_SUPPORTED_EXECS", "CUDA_SUPPORTED_TARGETS")
load("//toolchain/args:resource_directory_args.bzl", "resource_directory_args")
load("//toolchain/cuda:cc_toolchain.bzl", "cc_toolchain")

def declare_toolchains(*, execs = CUDA_SUPPORTED_EXECS, targets = CUDA_SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    for (exec_os, exec_cpu) in execs:
        # Reuse the stage-specific tool maps declared by the CPU bootstrap.
        for stage, setting in [
            ("stage1", "stage1_from_source"),
            ("stage2", "stage2_lto_and_fdo_instrumented"),
            ("stage3", "stage3_lto_and_fdo_applied"),
        ]:
            cuda_cc_toolchain_name = "{}_cuda_{}_{}_cc_toolchain".format(stage, exec_os, exec_cpu)
            resource_directory_args(
                name = cuda_cc_toolchain_name + "_resource_directory_args",
                compile_directory = ":{}_{}_{}/clang_resource_directory".format(stage, exec_os, exec_cpu),
                link_directory = ":{}_{}_{}/clang_resource_directory".format(stage, exec_os, exec_cpu),
            )
            cc_toolchain(
                name = cuda_cc_toolchain_name,
                extra_args = [cuda_cc_toolchain_name + "_resource_directory_args"],
                tool_map = select({
                    # We know that those targets are defined earlier by declare_bootstrap_toolchains
                    "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_apple_setting": ":{}_{}_{}/tools_with_libtool_for_runtime".format(stage, exec_os, exec_cpu),
                    "//conditions:default": ":{}_{}_{}/default_tools_for_runtime".format(stage, exec_os, exec_cpu),
                }),
            )

            for (target_os, target_cpu) in targets:
                native.toolchain(
                    name = "{}_cuda_{}_{}_to_{}_{}".format(stage, exec_os, exec_cpu, target_os, target_cpu),
                    exec_compatible_with = [
                        "@platforms//cpu:{}".format(exec_cpu),
                        "@platforms//os:{}".format(exec_os),
                    ],
                    target_compatible_with = [
                        "@platforms//cpu:{}".format(target_cpu),
                        "@platforms//os:{}".format(target_os),
                    ],
                    target_settings = [
                        "@llvm//toolchain:bootstrap_" + setting,
                        "@llvm//config:cuda_device_mode_enabled",
                    ],
                    toolchain = cuda_cc_toolchain_name,
                    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                    visibility = ["//visibility:public"],
                )
