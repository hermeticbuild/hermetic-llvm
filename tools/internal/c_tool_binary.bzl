load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

c_tool_binary, _c_tool_binary_internal = with_cfg(cc_binary).set(
    Label("//toolchain:cxxstdlib_mode"),
    "disabled",
).build()
