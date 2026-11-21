"""Tests that cc_stage0_object and the with_cfg stage0 runtimes share a configuration."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@with_cfg.bzl", "with_cfg")
load("//toolchain/runtimes:cc_stage0_object.bzl", "bootstrap_transition")
load("//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")

def _bin_dir_probe_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, "")
    return [DefaultInfo(files = depset([out]))]

bin_dir_probe = rule(
    implementation = _bin_dir_probe_impl,
)

stage0_bin_dir_probe, _stage0_bin_dir_probe_internal = configure_builder_for_runtimes(
    with_cfg(bin_dir_probe),
    "stage0",
).build()

StageRootsInfo = provider(
    doc = "Output roots of the same probe reached through both stage0 transitions.",
    fields = ["bootstrap", "with_cfg"],
)

def _stage_roots_impl(ctx):
    return [StageRootsInfo(
        bootstrap = ctx.file.bootstrap.root.path,
        with_cfg = ctx.file.with_cfg.root.path,
    )]

stage_roots = rule(
    implementation = _stage_roots_impl,
    attrs = {
        "bootstrap": attr.label(allow_single_file = True, cfg = bootstrap_transition),
        "with_cfg": attr.label(allow_single_file = True),
    },
)

def _stage0_features_test_impl(ctx):
    env = analysistest.begin(ctx)
    roots = analysistest.target_under_test(env)[StageRootsInfo]
    asserts.equals(env, roots.with_cfg, roots.bootstrap)
    return analysistest.end(env)

# cc_stage0_object is reached from runtimes that already set the linkmode, which
# bootstrap_transition leaves alone.
stage0_features_test = analysistest.make(
    _stage0_features_test_impl,
    config_settings = {
        str(Label("//runtimes:linkmode")): "static",
    },
)
