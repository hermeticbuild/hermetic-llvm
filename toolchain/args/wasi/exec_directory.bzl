"""Use an execution-platform directory in target-platform cc_args."""

def _exec_directory_impl(ctx):
    return [DefaultInfo(files = ctx.attr.src[DefaultInfo].files)]

exec_directory = rule(
    implementation = _exec_directory_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
    },
)
