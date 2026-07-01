load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

external_include_paths_ubsan_cc_binary, _external_include_paths_ubsan_cc_binary_internal = with_cfg(cc_binary).extend(
    "features",
    ["external_include_paths"],
).extend(
    "host_features",
    ["external_include_paths"],
).set(
    Label("@llvm//config:ubsan"),
    True,
).set(
    Label("@llvm//config:host_ubsan"),
    True,
).build()
