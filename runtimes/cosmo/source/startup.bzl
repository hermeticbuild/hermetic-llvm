"""Builds Cosmopolitan's CRT objects and linker scripts with Stage 1 Clang."""

def _startup_file_impl(ctx):
    source_root = ctx.label.workspace_root or "."
    args = ctx.actions.args()
    args.add("--target=" + ctx.attr.triple)
    args.add_all([
        "-nostdinc",
        "-D_COSMO_SOURCE",
        "-DSYSDEBUG",
        '-DMODE="opt"',
        "-iquote",
        source_root,
        "-isystem",
        source_root + "/libc/isystem",
    ])
    args.add("-include", ctx.file.normalize)
    if ctx.attr.linker_script:
        args.add_all(["-E", "-P", "-x", "c", "-D__LINKER__"])
    else:
        args.add_all(["-c", "-Wa,--noexecstack"])
    args.add("-o", ctx.outputs.out)
    args.add(ctx.file.src)
    ctx.actions.run(
        executable = ctx.attr.clang[DefaultInfo].files_to_run,
        arguments = [args],
        inputs = [ctx.file.src, ctx.file.normalize] + ctx.files.headers,
        outputs = [ctx.outputs.out],
        mnemonic = "CosmopolitanLinkerScript" if ctx.attr.linker_script else "CosmopolitanStartupObject",
    )

_startup_file = rule(
    implementation = _startup_file_impl,
    attrs = {
        "clang": attr.label(executable = True, cfg = "exec", mandatory = True),
        "headers": attr.label(allow_files = True, mandatory = True),
        "linker_script": attr.bool(),
        "normalize": attr.label(allow_single_file = [".inc"], mandatory = True),
        "out": attr.output(mandatory = True),
        "src": attr.label(allow_single_file = [".S", ".lds"], mandatory = True),
        "triple": attr.string(mandatory = True),
    },
)

def cosmo_stage1_tool(name, command):
    """Selects the source-built tool for the execution platform."""
    native.alias(
        name = name,
        actual = select({
            "@llvm//platforms/config:" + platform: "@llvm//toolchain:stage1_" + platform + "/bin/" + command
            for platform in ["linux_aarch64", "linux_x86_64", "macos_aarch64", "macos_x86_64"]
        }),
        visibility = ["//visibility:private"],
    )
    return name

def cosmo_startup_files(headers):
    """Adds CRT objects, the x86-64 APE object, and both linker scripts.

    Args:
        headers: Filegroup containing Cosmopolitan's source headers.
    """

    # Resolve the compiler after transitioning to the execution configuration.
    clang = ":" + cosmo_stage1_tool("startup_clang", "clang")
    for cpu, script in [("aarch64", "aarch64.lds"), ("x86_64", "ape.lds")]:
        triple = cpu + "-unknown-linux-gnu"
        _startup_file(
            name = cpu + "_crt",
            clang = clang,
            headers = headers,
            normalize = "libc/integral/normalize.inc",
            out = "startup/" + cpu + "/crt.o",
            src = "libc/crt/crt.S",
            triple = triple,
            visibility = ["//visibility:public"],
        )
        _startup_file(
            name = cpu + "_script",
            clang = clang,
            headers = headers,
            linker_script = True,
            normalize = "libc/integral/normalize.inc",
            out = "startup/" + cpu + "/" + script,
            src = "ape/" + script,
            triple = triple,
            visibility = ["//visibility:public"],
        )

    # The AArch64 linker consumes its own script and crt.o. Only the x86-64
    # linker consumes the APE object from ape/ape.S.
    _startup_file(
        name = "x86_64_ape",
        clang = clang,
        headers = headers,
        normalize = "libc/integral/normalize.inc",
        out = "startup/x86_64/ape.o",
        src = "ape/ape.S",
        triple = "x86_64-unknown-linux-gnu",
        visibility = ["//visibility:public"],
    )
