"""Execution toolchains for wasi-libc's CRT metadata tool."""

_TOOLCHAIN_TYPE = Label("//runtimes/wasi/tools:toolchain_type")

def _wasi_tools_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        wasm_tools = ctx.file.wasm_tools,
    )]

wasi_tools_toolchain = rule(
    implementation = _wasi_tools_toolchain_impl,
    attrs = {
        "wasm_tools": attr.label(allow_single_file = True, cfg = "exec", mandatory = True),
    },
)

def _wasm_tools_impl(ctx):
    binary = ctx.toolchains[_TOOLCHAIN_TYPE].wasm_tools
    out = ctx.actions.declare_file(ctx.label.name + (".exe" if binary.extension == "exe" else ""))
    ctx.actions.symlink(output = out, target_file = binary, is_executable = True)
    return [DefaultInfo(files = depset([out]), executable = out)]

resolved_wasm_tools = rule(
    implementation = _wasm_tools_impl,
    executable = True,
    toolchains = [_TOOLCHAIN_TYPE],
)
