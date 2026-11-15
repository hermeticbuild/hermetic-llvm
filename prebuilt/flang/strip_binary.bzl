"""Strip the source-built Flang executable before archiving it."""

def _strip_binary_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.run(
        executable = ctx.executable._strip,
        arguments = ["--strip-all", "-o", out.path, ctx.file.src.path],
        inputs = [ctx.file.src],
        outputs = [out],
        tools = [ctx.attr._strip[DefaultInfo].files_to_run],
        mnemonic = "StripFlang",
    )
    return [DefaultInfo(files = depset([out]))]

strip_binary = rule(
    implementation = _strip_binary_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "_strip": attr.label(
            default = "@llvm-toolchain-minimal-linux-amd64//:bin/llvm-strip",
            executable = True,
            allow_files = True,
            cfg = "exec",
        ),
    },
)
