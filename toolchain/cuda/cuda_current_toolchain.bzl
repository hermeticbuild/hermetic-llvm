"""Exports components from the currently selected CUDA toolchain."""

_CUDA_TOOLCHAIN_TYPE = "@cuda_toolchain_types//cuda:toolchain_type"
_CUDA_TOOLCHAIN_COMPONENTS = [
    "ptxas",
    "fatbinary",
    "cuda_path",
]

def _cuda_current_toolchain_component(ctx):
    cuda_toolchain = ctx.toolchains[_CUDA_TOOLCHAIN_TYPE].cuda
    return getattr(cuda_toolchain, ctx.attr.component)

def _cuda_current_toolchain_file_component_impl(ctx):
    component = _cuda_current_toolchain_component(ctx)
    return [DefaultInfo(files = depset([component]))]

def _declare_executable_output(ctx, executable):
    output_name = ctx.label.name
    if executable.extension and not output_name.endswith("." + executable.extension):
        output_name += "." + executable.extension

    out = ctx.actions.declare_file(output_name)
    ctx.actions.symlink(
        output = out,
        target_file = executable,
    )
    return out

def _cuda_current_toolchain_executable_component_impl(ctx):
    component = _cuda_current_toolchain_component(ctx)
    out = _declare_executable_output(ctx, component)

    return [
        DefaultInfo(
            executable = out,
            files = depset([out]),
        ),
    ]

_cuda_current_toolchain_file_component = rule(
    implementation = _cuda_current_toolchain_file_component_impl,
    attrs = {
        "component": attr.string(
            mandatory = True,
            values = _CUDA_TOOLCHAIN_COMPONENTS,
        ),
    },
    toolchains = [_CUDA_TOOLCHAIN_TYPE],
)

_cuda_current_toolchain_executable_component = rule(
    implementation = _cuda_current_toolchain_executable_component_impl,
    attrs = {
        "component": attr.string(
            mandatory = True,
            values = _CUDA_TOOLCHAIN_COMPONENTS,
        ),
    },
    executable = True,
    toolchains = [_CUDA_TOOLCHAIN_TYPE],
)

def cuda_current_toolchain_component(name, component, executable = False, **kwargs):
    if executable:
        _cuda_current_toolchain_executable_component(
            name = name,
            component = component,
            **kwargs
        )
        return

    _cuda_current_toolchain_file_component(
        name = name,
        component = component,
        **kwargs
    )
