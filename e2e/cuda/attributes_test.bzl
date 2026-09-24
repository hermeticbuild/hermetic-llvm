"""Checks that CUDA compilation honors disabled features in both passes."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _disabled_dbg_test_impl(ctx):
    env = analysistest.begin(ctx)
    compiles = [a for a in analysistest.target_actions(env) if a.mnemonic == "CppCompile"]
    asserts.true(env, len(compiles) > 0, "Expected a source compilation action")
    for action in compiles:
        asserts.false(env, "-g" in action.argv, "features = ['-dbg'] must disable debug info")
    return analysistest.end(env)

host_features_test = analysistest.make(
    _disabled_dbg_test_impl,
    config_settings = {"//command_line_option:compilation_mode": "dbg"},
)

device_features_test = analysistest.make(
    _disabled_dbg_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
        str(Label("@llvm//config:cuda_device_mode")): True,
        str(Label("@llvm//config:nvidia_compute_capability")): "sm_120",
    },
)
