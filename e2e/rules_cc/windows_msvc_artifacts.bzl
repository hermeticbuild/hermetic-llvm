"""Target transitions for MSVC artifact and native execution tests."""

def _crt_transition_impl(settings, attr):
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
        # The CI path-mapping opt-in matches CppCompile for every toolchain.
        # MSVC compile actions cannot consume those mapped paths yet.
        "//command_line_option:modify_execution_info": [],
        "//command_line_option:features": features,
        "//command_line_option:platforms": str(attr.target_platform),
    }

_crt_transition = transition(
    implementation = _crt_transition_impl,
    inputs = ["//command_line_option:features"],
    outputs = [
        "//command_line_option:modify_execution_info",
        "//command_line_option:features",
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

def _windows_msvc_native_test_impl(ctx):
    binary = ctx.attr.binary[0][DefaultInfo]
    executable = ctx.actions.declare_file(ctx.label.name + ".exe")
    ctx.actions.symlink(
        output = executable,
        target_file = binary.files_to_run.executable,
    )
    return [DefaultInfo(
        executable = executable,
        runfiles = binary.default_runfiles,
    )]

windows_msvc_native_test = rule(
    implementation = _windows_msvc_native_test_impl,
    attrs = {
        "binary": attr.label(
            cfg = _crt_transition,
            executable = True,
            mandatory = True,
        ),
        "static_crt": attr.bool(default = True),
        "target_platform": attr.label(mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    test = True,
)
