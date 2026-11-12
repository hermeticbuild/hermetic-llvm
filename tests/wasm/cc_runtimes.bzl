"""Asserts that C++ targets get no implicit runtime libraries."""

load("@bazel_features//:features.bzl", "bazel_features")

_CC_RUNTIMES_TOOLCHAIN_TYPE = "@bazel_tools//tools/cpp:cc_runtimes_toolchain_type"

# Matches the registration condition in //toolchain:declare_toolchains.bzl.
_HAS_CC_RUNTIMES = bazel_features.cc.cc_common_is_in_rules_cc

def _no_cc_runtimes_impl(ctx):
    toolchain = ctx.toolchains[_CC_RUNTIMES_TOOLCHAIN_TYPE] if _HAS_CC_RUNTIMES else None
    if toolchain and toolchain.cc_runtimes_info.runtimes:
        fail("C++ targets depend on implicit runtimes: %s" % [
            str(runtime.label)
            for runtime in toolchain.cc_runtimes_info.runtimes
        ])
    return [DefaultInfo()]

no_cc_runtimes = rule(
    implementation = _no_cc_runtimes_impl,
    toolchains = [
        config_common.toolchain_type(_CC_RUNTIMES_TOOLCHAIN_TYPE, mandatory = False),
    ] if _HAS_CC_RUNTIMES else [],
)
