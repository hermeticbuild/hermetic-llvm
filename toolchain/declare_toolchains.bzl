load("//platforms:common.bzl", "MSVC_TARGET_STAGE0_SUPPORTED_EXECS", "SUPPORTED_EXECS", "SUPPORTED_TARGETS")
load("//toolchain:merged_resource_directory.bzl", "merged_resource_directory")
load("//toolchain:selects.bzl", "platform_cc_tool_map", "platform_module_map", "platform_resource_dir")
load("//toolchain/args:resource_directory_args.bzl", "resource_directory_args")
load(":cc_toolchain.bzl", "cc_toolchain")

def declare_toolchains(*, execs = SUPPORTED_EXECS, targets = SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    for (exec_os, exec_cpu) in execs:
        cc_toolchain_name = exec_os + "_" + exec_cpu + "_cc_toolchain"

        # Bind the directory beside the tool map, before another rule's exec
        # transition can select a different compiler installation.
        merged_resource_directory(
            name = cc_toolchain_name + "_resource_directory",
            parent = platform_resource_dir(exec_os, exec_cpu),
            srcs = ["@llvm//runtimes:resource_directory"],
        )
        resource_directory_args(
            name = cc_toolchain_name + "_resource_directory_args",
            compile_directory = platform_resource_dir(exec_os, exec_cpu),
            link_directory = cc_toolchain_name + "_resource_directory",
        )

        # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
        # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
        # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
        cc_toolchain(
            name = cc_toolchain_name,
            tool_map = platform_cc_tool_map(exec_os, exec_cpu),
            module_map = platform_module_map(exec_os, exec_cpu),
            # Paths below describe the concrete execution filesystem. Keep
            # target semantics in //toolchain's ordered argument composition.
            extra_args = [cc_toolchain_name + "_resource_directory_args"] + select({
                "@llvm//platforms/config:windows_x86_64_msvc": [
                    "@llvm//toolchain/args/windows/msvc:normalized_default_libs_for_runtime",
                    "@llvm//toolchain/args/windows/msvc:normalized_sdk_compile_args",
                ],
                "@llvm//platforms/config:windows_aarch64_msvc": [
                    "@llvm//toolchain/args/windows/msvc:normalized_default_libs_for_runtime",
                    "@llvm//toolchain/args/windows/msvc:normalized_sdk_compile_args",
                ],
                "//conditions:default": [],
            }),
        )

        for (target_os, target_cpu) in targets:
            target_settings = ["@llvm//toolchain:bootstrap_stage0_prebuilt_seed"]
            if target_os == "windows":
                target_settings.append("@llvm//platforms/config:windows_" + target_cpu + "_mingw_compatible")

            native.toolchain(
                name = exec_os + "_" + exec_cpu + "_to_" + target_os + "_" + target_cpu,
                exec_compatible_with = [
                    "@platforms//cpu:" + exec_cpu,
                    "@platforms//os:" + exec_os,
                ],
                target_compatible_with = [
                    "@platforms//cpu:" + target_cpu,
                    "@platforms//os:" + target_os,
                ],
                target_settings = target_settings,
                toolchain = cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )

            if target_os == "windows" and (exec_os, exec_cpu) in MSVC_TARGET_STAGE0_SUPPORTED_EXECS:
                native.toolchain(
                    name = exec_os + "_" + exec_cpu + "_to_" + target_os + "_" + target_cpu + "_msvc",
                    exec_compatible_with = [
                        "@platforms//cpu:" + exec_cpu,
                        "@platforms//os:" + exec_os,
                    ],
                    target_compatible_with = [
                        "@platforms//cpu:" + target_cpu,
                        "@platforms//os:" + target_os,
                    ],
                    target_settings = [
                        "@llvm//toolchain:bootstrap_stage0_prebuilt_seed",
                        "@llvm//platforms/config:windows_" + target_cpu + "_msvc",
                    ],
                    toolchain = cc_toolchain_name,
                    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                    visibility = ["//visibility:public"],
                )
