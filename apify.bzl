"""Packages Cosmopolitan ELF executables as an Actually Portable Executable."""

def _apify_binary_impl(ctx):
    apelink = ctx.file.apelink
    args = ctx.actions.args()
    args.add(apelink)
    args.add("-o", ctx.outputs.out)

    inputs = []
    runfiles = []
    if ctx.file.x86_64:
        args.add("-l", ctx.file._x86_loader)
        inputs.extend([ctx.file._x86_loader, ctx.file.x86_64])
        runfiles.append(ctx.attr.x86_64[DefaultInfo].default_runfiles)
    if ctx.file.aarch64:
        args.add("-l", ctx.file._arm_loader)
        args.add("-M", ctx.file._macos_arm_loader)
        inputs.extend([ctx.file._arm_loader, ctx.file._macos_arm_loader, ctx.file.aarch64])
        runfiles.append(ctx.attr.aarch64[DefaultInfo].default_runfiles)
    if not inputs:
        fail("Set x86_64, aarch64, or both")

    args.add_all([elf for elf in [ctx.file.x86_64, ctx.file.aarch64] if elf])
    ctx.actions.run(
        executable = ctx.file._loader,
        arguments = [args],
        tools = [apelink],
        inputs = inputs,
        outputs = [ctx.outputs.out],
        mnemonic = "Apelink",
    )
    return [DefaultInfo(
        executable = ctx.outputs.out,
        runfiles = ctx.runfiles().merge_all(runfiles),
    )]

_apify_binary = rule(
    implementation = _apify_binary_impl,
    executable = True,
    attrs = {
        "aarch64": attr.label(allow_single_file = True),
        "out": attr.output(mandatory = True),
        "x86_64": attr.label(allow_single_file = True),
        "apelink": attr.label(default = "@cosmopolitan_sdk//:bin/apelink", allow_single_file = True, cfg = "exec"),
        "_arm_loader": attr.label(default = "@cosmopolitan_sdk//:bin/ape-aarch64.elf", allow_single_file = True),
        "_loader": attr.label(default = "//runtimes/cosmo:ape_loader", allow_single_file = True, cfg = "exec"),
        "_macos_arm_loader": attr.label(default = "@cosmopolitan_sdk//:bin/ape-m1.c", allow_single_file = True),
        "_x86_loader": attr.label(default = "@cosmopolitan_sdk//:bin/ape-x86_64.elf", allow_single_file = True),
    },
)

def apify_binary(name, *, x86_64 = None, aarch64 = None, apelink = None, **kwargs):
    """Packages Cosmopolitan ELF files with apelink.

    Args:
        name: Rule name. The output is named <name>.com.
        x86_64: Optional Cosmopolitan x86-64 ELF target.
        aarch64: Optional Cosmopolitan AArch64 ELF target.
        apelink: Optional apelink executable built for the execution platform.
        **kwargs: Common Bazel rule attributes.
    """
    _apify_binary(name = name, x86_64 = x86_64, aarch64 = aarch64, apelink = apelink, out = name + ".com", **kwargs)
