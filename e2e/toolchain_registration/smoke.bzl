"""Exercise toolchain registration without using a C++ toolchain."""

def _toolchain_impl(_ctx):
    return [platform_common.ToolchainInfo()]

smoke_toolchain = rule(implementation = _toolchain_impl)

def _smoke_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, "ok\n")
    return [DefaultInfo(files = depset([out]))]

smoke = rule(
    implementation = _smoke_impl,
    toolchains = ["//:toolchain_type"],
)
