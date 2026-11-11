"""C++ toolchain args and feature sets analysed once for every runtime stage."""

load("@rules_cc//cc/toolchains:args_list.bzl", "cc_args_list")
load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")

def _reset_stage_impl(_settings, _attr):
    return {
        "//toolchain:runtime_stage": "complete",
        "//runtimes:linkmode": "dynamic",
    }

_reset_stage = transition(
    implementation = _reset_stage_impl,
    inputs = [],
    outputs = ["//toolchain:runtime_stage", "//runtimes:linkmode"],
)

def _super_impl(ctx):
    return ctx.super()

stage_independent_args_list = rule(
    implementation = _super_impl,
    parent = cc_args_list,
    cfg = _reset_stage,
    doc = "A cc_args_list analysed with the complete runtime stage and dynamic linkmode.",
)

stage_independent_feature_set = rule(
    implementation = _super_impl,
    parent = cc_feature_set,
    cfg = _reset_stage,
    doc = "A cc_feature_set analysed with the complete runtime stage and dynamic linkmode.",
)
