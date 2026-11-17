"""Builds binaries with --@llvm//config:musl_llvm_libc_string_functions."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

llvm_libc_string_functions_cc_binary, _llvm_libc_string_functions_cc_binary_internal = with_cfg(
    cc_binary,
).set(
    Label("//config:musl_llvm_libc_string_functions"),
    True,
).build()
