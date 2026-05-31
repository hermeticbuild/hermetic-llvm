load("@llvm//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

_exec_stage0_binary_builder = with_cfg(
    cc_binary,
)

exec_stage0_binary, _exec_stage0_binary_internal = configure_builder_for_runtimes(_exec_stage0_binary_builder, "stage0").build()

_exec_stage1_hosted_binary_builder = with_cfg(
    cc_binary,
)

exec_stage1_hosted_binary, _exec_stage1_hosted_binary_internal = configure_builder_for_runtimes(_exec_stage1_hosted_binary_builder, "stage1_hosted").build()
