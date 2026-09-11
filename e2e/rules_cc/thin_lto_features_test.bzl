"""Tests shared ThinLTO backend feature selection in the LLVM toolchain."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

_SHARED_BACKEND_FEATURES = [
    "thin_lto_linkstatic_tests_use_shared_nonlto_backends",
    "thin_lto_all_linkstatic_use_shared_nonlto_backends",
]

def _thin_lto_features_test_impl(ctx):
    env = analysistest.begin(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = find_cpp_toolchain(ctx),
        requested_features = ["thin_lto"] + ctx.attr.shared_backend_features,
    )
    thin_lto_enabled = cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = "thin_lto",
    )
    if not thin_lto_enabled:
        fail("%s: thin_lto was not enabled" % ctx.label)
    for feature_name in _SHARED_BACKEND_FEATURES:
        enabled = cc_common.is_enabled(
            feature_configuration = feature_configuration,
            feature_name = feature_name,
        )
        expected = feature_name in ctx.attr.shared_backend_features
        if enabled != expected:
            fail("%s: expected %s=%s, got %s" % (ctx.label, feature_name, expected, enabled))
    return analysistest.end(env)

thin_lto_features_test = rule(
    implementation = _thin_lto_features_test_impl,
    analysis_test = True,
    attrs = {
        "shared_backend_features": attr.string_list(),
    },
    fragments = ["cpp"],
    test = True,
    toolchains = use_cpp_toolchain(),
)
