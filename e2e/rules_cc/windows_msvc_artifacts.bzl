"""Configuration-wide CRT selection for MSVC artifact tests."""

def _crt_transition_impl(settings, attr):
    # type: (_CrtInputs, _CrtAttrs) -> _CrtOutputs
    features = [
        feature
        for feature in settings["//command_line_option:features"]
        if feature not in [
            "-dynamic_link_msvcrt",
            "-static_link_msvcrt",
            "dynamic_link_msvcrt",
            "static_link_msvcrt",
        ]
    ]
    features.extend(
        ["-dynamic_link_msvcrt", "static_link_msvcrt"] if attr.static_crt else ["-static_link_msvcrt", "dynamic_link_msvcrt"],
    )
    return {
        "//command_line_option:features": features,
        "//command_line_option:platforms": str(attr.target_platform),
    }

_crt_transition = transition(
    implementation = _crt_transition_impl,
    inputs = ["//command_line_option:features"],
    outputs = [
        "//command_line_option:features",
        "//command_line_option:platforms",
    ],
)

def _windows_msvc_artifacts_impl(ctx):
    # type: (...) -> list[DefaultInfo]
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
