"""Configuration-wide CRT selection for MSVC artifact tests."""

def _crt_transition_impl(_settings, attr):
    return {
        "@llvm//toolchain/features/msvc:crt_mode": "static" if attr.static_crt else "dynamic",
        "//command_line_option:platforms": str(attr.target_platform),
    }

_crt_transition = transition(
    implementation = _crt_transition_impl,
    inputs = [],
    outputs = [
        "@llvm//toolchain/features/msvc:crt_mode",
        "//command_line_option:platforms",
    ],
)

def _windows_msvc_artifacts_impl(ctx):
    return [DefaultInfo(
        files = depset(transitive = [
            target[DefaultInfo].files
            for target in ctx.attr.targets
        ] + [
            target[DefaultInfo].default_runfiles.files
            for target in ctx.attr.targets
        ]),
    )]

windows_msvc_artifacts = rule(
    implementation = _windows_msvc_artifacts_impl,
    attrs = {
        "static_crt": attr.bool(),
        "targets": attr.label_list(
            allow_empty = False,
            cfg = _crt_transition,
        ),
        "target_platform": attr.label(mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
