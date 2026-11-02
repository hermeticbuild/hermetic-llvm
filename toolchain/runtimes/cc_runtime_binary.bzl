load("@bazel_lib//lib:transitions.bzl", "platform_transition_binary")
load("@llvm//platforms:common.bzl", "SUPPORTED_EXECS")
load("@llvm//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_binary,
)

cc_runtime_stage0_binary, _cc_runtime_stage0_binary_internal = configure_builder_for_runtimes(_builder.clone(), "stage0").build()
cc_runtime_stage1_hosted_binary, _cc_runtime_stage1_hosted_binary_internal = configure_builder_for_runtimes(_builder.clone(), "stage1_hosted").build()

def cc_runtime_stage1_hosted_tool(name, visibility = None, **kwargs):
    """Builds a stage 1 tool that can run without an installed libc on Linux."""
    native_tool = "native/" + name
    cc_runtime_stage1_hosted_binary(
        name = native_tool,
        visibility = ["//visibility:private"],
        **kwargs
    )

    tools = {"//conditions:default": ":" + native_tool}
    for os, cpu in SUPPORTED_EXECS:
        if os == "linux":
            tool = name + "-" + cpu
            platform_transition_binary(
                name = tool,
                binary = ":" + native_tool,
                target_compatible_with = [
                    "@platforms//os:linux",
                    "@platforms//cpu:" + cpu,
                ],
                target_platform = Label("//platforms:linux_{}_musl".format(cpu)),
                visibility = ["//visibility:private"],
            )
            tools[Label("//platforms/config:linux_" + cpu)] = ":" + tool

    native.alias(
        name = name,
        actual = select(tools),
        visibility = visibility,
    )
