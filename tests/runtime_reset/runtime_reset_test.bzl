"""Tests that settings the runtimes do not read leave them in one configuration."""

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

runtime_bin_dir_probe, _runtime_bin_dir_probe_internal = configure_builder_for_runtimes(
    with_cfg(bin_dir_probe),
    "stage1",
).build()

def _stage0_bin_dir_probe_impl(ctx):
    return [DefaultInfo(files = depset([ctx.file.probe]))]

stage0_bin_dir_probe = rule(
    implementation = _stage0_bin_dir_probe_impl,
    attrs = {
        "probe": attr.label(allow_single_file = True, cfg = bootstrap_transition),
    },
)

def _plain_impl(_settings, _attr):
    return {
        "//command_line_option:collect_code_coverage": False,
        "//command_line_option:instrument_test_targets": False,
        "//command_line_option:instrumentation_filter": "-/javatests[/:],-/test/java[/:]",
        "//runtimes:linkmode": "static",
    }

def _instrumented_impl(_settings, _attr):
    return {
        "//command_line_option:collect_code_coverage": True,
        "//command_line_option:instrument_test_targets": True,
        "//command_line_option:instrumentation_filter": "^//tests[/:]",
        "//runtimes:linkmode": "dynamic",
    }

_OUTPUTS = [
    "//command_line_option:collect_code_coverage",
    "//command_line_option:instrument_test_targets",
    "//command_line_option:instrumentation_filter",
    "//runtimes:linkmode",
]

_plain_transition = transition(
    implementation = _plain_impl,
    inputs = [],
    outputs = _OUTPUTS,
)

_instrumented_transition = transition(
    implementation = _instrumented_impl,
    inputs = [],
    outputs = _OUTPUTS,
)

ResetRootsInfo = provider(
    doc = "Output roots of the runtime probes reached from two configurations.",
    fields = ["instrumented", "plain"],
)

def _roots(targets):
    return [target[DefaultInfo].files.to_list()[0].root.path for target in targets]

def _reset_roots_impl(ctx):
    return [ResetRootsInfo(
        instrumented = _roots(ctx.attr.instrumented),
        plain = _roots(ctx.attr.plain),
    )]

reset_roots = rule(
    implementation = _reset_roots_impl,
    attrs = {
        "instrumented": attr.label_list(cfg = _instrumented_transition),
        "plain": attr.label_list(cfg = _plain_transition),
    },
)

def _runtime_reset_test_impl(ctx):
    env = analysistest.begin(ctx)
    roots = analysistest.target_under_test(env)[ResetRootsInfo]
    asserts.equals(env, roots.plain, roots.instrumented)
    return analysistest.end(env)

runtime_reset_test = analysistest.make(_runtime_reset_test_impl)
