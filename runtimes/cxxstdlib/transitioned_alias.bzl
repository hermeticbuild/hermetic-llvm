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
    return [
        DefaultInfo(
            files = default.files,
            runfiles = default.default_runfiles,
        ),
    ]

transitioned_alias = rule(
    implementation = _transitioned_alias_impl,
    attrs = {
        "actual": attr.label(cfg = disabled_cxxstdlib_transition, mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
