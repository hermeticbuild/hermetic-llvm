load("@llvm//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    native.filegroup,
)

stage0_filegroup, _stage0_filegroup_internal = configure_builder_for_runtimes(_builder, "stage0").build()
