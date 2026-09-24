load("//platforms:common.bzl", "CUDA_SUPPORTED_EXECS", "CUDA_SUPPORTED_TARGETS")
load("//toolchain:selects.bzl", "platform_cc_tool_map", "platform_module_map", "platform_resource_dir")
load("//toolchain/args:resource_directory_args.bzl", "resource_directory_args")
load(":cc_toolchain.bzl", "cc_toolchain")

def declare_toolchains(*, execs = CUDA_SUPPORTED_EXECS, targets = CUDA_SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    for (exec_os, exec_cpu) in execs:
        # TODO(cerisier): This will only work with prebuilts LLVM >= 22.x
        # Since before that we didn't have nvptx support in the prebuilts.
        cuda_cc_toolchain_name = "cuda_{}_{}_cc_toolchain".format(exec_os, exec_cpu)
        resource_directory_args(
            name = cuda_cc_toolchain_name + "_resource_directory_args",
            compile_directory = platform_resource_dir(exec_os, exec_cpu),
            link_directory = platform_resource_dir(exec_os, exec_cpu),
        )
        cc_toolchain(
            name = cuda_cc_toolchain_name,
            tool_map = platform_cc_tool_map(exec_os, exec_cpu),
            module_map = platform_module_map(exec_os, exec_cpu),
            extra_args = [cuda_cc_toolchain_name + "_resource_directory_args"],
        )

        for (target_os, target_cpu) in targets:
            native.toolchain(
                name = "cuda_{}_{}_to_{}_{}".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                ],
                target_settings = [
                    "@llvm//toolchain:bootstrap_stage0_prebuilt_seed",
                    "@llvm//config:cuda_device_mode_enabled",
                ],
                toolchain = cuda_cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )
