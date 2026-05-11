load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")

def _disabled_cxxstdlib_transition_impl(_settings, _attr):
    return {
        "//toolchain:cxxstdlib_mode": "disabled",
    }

disabled_cxxstdlib_transition = transition(
    implementation = _disabled_cxxstdlib_transition_impl,
    inputs = [],
    outputs = [
        "//toolchain:cxxstdlib_mode",
    ],
)

def _transitioned_alias_impl(ctx):
    actual = ctx.attr.actual
    if type(actual) == "list":
        actual = actual[0]
    default = actual[DefaultInfo]
    providers = [
        DefaultInfo(
            files = default.files,
            runfiles = default.default_runfiles,
        ),
    ]
    if DirectoryInfo in actual:
        providers.append(actual[DirectoryInfo])
    return providers

transitioned_alias = rule(
    implementation = _transitioned_alias_impl,
    attrs = {
        "actual": attr.label(cfg = disabled_cxxstdlib_transition, mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
