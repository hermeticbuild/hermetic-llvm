load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

cc_runtime_tool_binary, _cc_runtime_tool_binary_internal = with_cfg(cc_binary).set(
    Label("//toolchain:runtime_stage"),
    "stage1",
).build()
