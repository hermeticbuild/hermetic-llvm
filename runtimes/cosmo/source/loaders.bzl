"""Builds the APE loaders from Cosmopolitan's ape/BUILD.mk recipes."""

load(":startup.bzl", "cosmo_stage1_tool")

def _ape_loader_impl(ctx):
    x86_64 = ctx.attr.cpu == "x86_64"
    objects = []
    for src in ctx.files.srcs:
        obj = ctx.actions.declare_file(ctx.label.name + "/" + src.basename + ".o")
        args = ctx.actions.args()
        args.add("--target=" + ctx.attr.cpu + "-unknown-linux-gnu")
        args.add_all(["-nostdinc", "-iquote", ctx.label.workspace_root, "-fpie"])
        if src.extension == "c":
            args.add_all([
                "-DSUPPORT_VECTOR=" + ("121" if x86_64 else "33"),
                "-DNDEBUG",
                "-Os",
                "-ffreestanding",
                "-mgeneral-regs-only",
                "-fno-asynchronous-unwind-tables",
                "-fno-stack-protector",
                "-fno-ident",
            ])
        else:
            args.add_all(["-D_COSMO_SOURCE", "-Wa,--noexecstack"])
        args.add("-o", obj)
        args.add("-c", src)
        ctx.actions.run(
            executable = ctx.attr.clang[DefaultInfo].files_to_run,
            arguments = [args],
            inputs = [src] + ctx.files.headers,
            outputs = [obj],
            mnemonic = "CosmopolitanLoaderCompile",
        )
        objects.append(obj)

    # The x86-64 ELF includes the Mach-O header that objbincopy fills in.
    link = ctx.actions.args()
    link.add(ctx.file.bfd)
    link.add_all(["-static", "-nostdlib", "--no-dynamic-linker"])
    if x86_64:
        link.add_all(["-z", "separate-code", "-z", "common-page-size=0x1000", "-z", "max-page-size=0x10000"])
        link.add("-T", ctx.file.script)
    else:
        link.add_all(["-pie", "-z", "norelro", "-z", "common-page-size=0x4000", "-z", "max-page-size=0x4000"])
    linked = ctx.actions.declare_file(ctx.label.name + ".dbg")
    link.add("-o", linked)
    link.add_all(objects)
    ctx.actions.run(
        executable = ctx.file._seed_loader,
        arguments = [link],
        tools = [ctx.file.bfd],
        inputs = objects + ctx.files.script,
        outputs = [linked],
        mnemonic = "CosmopolitanLoaderLink",
    )

    elf = ctx.outputs.elf
    if x86_64:
        for flag, out in [("-f", elf), ("-fm", ctx.outputs.macho)]:
            args = ctx.actions.args()
            args.add(ctx.file.converter)
            args.add(flag)
            args.add("-o", out)
            args.add(linked)
            ctx.actions.run(
                executable = ctx.file._seed_loader,
                arguments = [args],
                inputs = [linked],
                tools = [ctx.file.converter],
                outputs = [out],
                mnemonic = "CosmopolitanLoaderConvert",
            )
    else:
        objcopy = ctx.attr.objcopy[DefaultInfo].files_to_run
        ctx.actions.run_shell(
            command = """
set -eu
"$1" -g "$2" "$3"
"$4" "$5" "$3"
""",
            arguments = [objcopy.executable.path, linked.path, elf.path, ctx.file._seed_loader.path, ctx.file.converter.path],
            inputs = [linked],
            tools = [objcopy, ctx.file._seed_loader, ctx.file.converter],
            outputs = [elf],
            mnemonic = "CosmopolitanLoaderFixup",
        )
    return DefaultInfo(files = depset([elf] + ([ctx.outputs.macho] if x86_64 else [])))

_ape_loader = rule(
    implementation = _ape_loader_impl,
    attrs = {
        "bfd": attr.label(allow_single_file = True, cfg = "exec", mandatory = True),
        "clang": attr.label(executable = True, cfg = "exec", mandatory = True),
        "converter": attr.label(allow_single_file = True, cfg = "exec", mandatory = True),
        "cpu": attr.string(mandatory = True, values = ["aarch64", "x86_64"]),
        "elf": attr.output(mandatory = True),
        "headers": attr.label_list(allow_files = [".h"], mandatory = True),
        "macho": attr.output(),
        "objcopy": attr.label(executable = True, cfg = "exec"),
        "script": attr.label(allow_single_file = [".lds"]),
        "srcs": attr.label_list(allow_files = [".S", ".c"], mandatory = True),
        "_seed_loader": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = "//runtimes/cosmo:ape_loader",
        ),
    },
)

def cosmo_ape_loaders():
    """Declares both ELF loaders and the x86-64 Mach-O loader."""
    cosmo_stage1_tool("loader_clang", "clang")
    cosmo_stage1_tool("loader_objcopy", "llvm-objcopy")
    srcs = ["ape/start.S", "ape/loader.c", "ape/launch.S", "ape/systemcall.S"]
    headers = ["ape/ape.h", "libc/dce.h", "libc/macros.h"]
    _ape_loader(
        name = "ape_aarch64",
        bfd = "@cosmopolitan_sdk//:aarch64_bfd",
        clang = ":loader_clang",
        converter = "@llvm//prebuilt/cosmo:bootstrap_fixupobj",
        cpu = "aarch64",
        elf = "ape-aarch64.elf",
        headers = headers,
        objcopy = ":loader_objcopy",
        srcs = srcs,
        tags = ["manual"],
        visibility = ["//visibility:public"],
    )
    _ape_loader(
        name = "ape_x86_64",
        bfd = "@cosmopolitan_sdk//:x86_64_bfd",
        clang = ":loader_clang",
        converter = "@llvm//prebuilt/cosmo:bootstrap_objbincopy",
        cpu = "x86_64",
        elf = "ape-x86_64.elf",
        headers = headers + ["libc/macho.h", "libc/sysv/consts/prot.h"],
        macho = "ape-x86_64.macho",
        script = "ape/loader.lds",
        srcs = ["ape/loader-macho.S"] + srcs,
        tags = ["manual"],
        visibility = ["//visibility:public"],
    )
