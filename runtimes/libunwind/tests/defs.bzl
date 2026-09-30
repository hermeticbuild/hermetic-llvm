"""Rule wrappers that build with --//config:experimental_use_llvm_libgcc."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

llvm_libgcc_cc_binary, _llvm_libgcc_cc_binary_internal = with_cfg(cc_binary).set(
    Label("//config:experimental_use_llvm_libgcc"),
    True,
).build()
