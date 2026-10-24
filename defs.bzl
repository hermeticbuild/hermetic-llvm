def exec_test(
        rule,
        *,
        name,
        tags = [],
        args = [],
        env = {},
        data = [],
        tools = [],
        **kwargs):
    inner_tags = list(tags)  # type: _InnerTags[T]
    if "manual" not in tags:
        inner_tags.append("manual")

    # The inner executable is built in the exec configuration. Keep target
    # artifacts on the outer test unless an inner rule attribute itself uses a
    # location expansion for one of them (for example go_test.x_defs), in which
    # case the caller must also declare it in inner_data.
    forwarded = dict(kwargs)
    forwarded.pop("inner_data", None)

    # Allocate omitted inner_data here so calls cannot share the default list.
    rule(
        name = name + "_",
        data = kwargs["inner_data"] if "inner_data" in kwargs else [],
        tags = inner_tags,
        **forwarded
    )

    _exec_test(
        name = name,
        inner = name + "_",
        tags = tags,
        args = args,
        env = env,
        data = data,
        tools = tools,
        target_compatible_with = kwargs.get("target_compatible_with", []),
    )

def _exec_test_impl(ctx):
    inner = ctx.attr.inner[DefaultInfo]
    inner_executable = inner.files_to_run.executable
    out = ctx.actions.declare_file(ctx.label.name + ".exe") if inner_executable.extension == "exe" else ctx.outputs.executable

    ctx.actions.symlink(
        target_file = inner_executable,
        output = out,
    )

    data = ctx.attr.data + ctx.attr.tools
    runfiles = ctx.runfiles(ctx.files.data + ctx.files.tools).merge_all([
        target[DefaultInfo].default_runfiles
        for target in data
    ])

    return [
        DefaultInfo(
            files = depset([out]),
            executable = out,
            runfiles = runfiles.merge(inner.default_runfiles),
        ),
        RunEnvironmentInfo(
            environment = {
                k: ctx.expand_location(v, data)
                for k, v in ctx.attr.env.items()
            },
        ),
    ]

_exec_test = rule(
    implementation = _exec_test_impl,
    attrs = {
        "inner": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "data": attr.label_list(
            doc = "The service manager will merge these variables into the environment when spawning the underlying binary.",
            allow_files = True,
        ),
        "tools": attr.label_list(
            doc = "The service manager will merge these variables into the environment when spawning the underlying binary.",
            cfg = "exec",
            allow_files = True,
        ),
        "env": attr.string_dict(
            doc = "The service manager will merge these variables into the environment when spawning the underlying binary.",
        ),
    },
    # The executable is built in the rule's exec configuration. Override
    # Bazel's implicit target-matching test toolchain so the test runner uses
    # the same unconstrained execution-platform selection as this rule.
    exec_groups = {
        "test": exec_group(),
    },
    test = True,
)
