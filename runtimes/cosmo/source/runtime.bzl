"""Bazel C and C++ targets for the Cosmopolitan libraries."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@with_cfg.bzl", "with_cfg")
load("//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")

def _archive_priority(obj):
    return 1 if obj.basename.removesuffix(".o").removesuffix(".pic") in ["kprintf.greg", "personality"] else 0

def _cosmo_archive_impl(ctx):
    objects = []
    for dep in ctx.attr.deps:
        for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                objects.extend(library.objects or library.pic_objects)
    objects = depset(objects).to_list()

    # Upstream runs fixupobj on compiler outputs before invoking ar. In
    # particular, x86-64 IFUNC resolvers need the relocations in the .o files.
    fixed = []
    for i in range(0, len(objects), 64):
        batch = objects[i:i + 64]
        outputs = [
            ctx.actions.declare_file("{}/fixed/{}/{}".format(ctx.label.name, i + j, obj.basename))
            for j, obj in enumerate(batch)
        ]
        args = ctx.actions.args()
        args.add(ctx.file._loader)
        args.add(ctx.file._fixupobj)
        for src, dst in zip(batch, outputs):
            args.add(src)
            args.add(dst)
        ctx.actions.run_shell(
            command = """
set -eu
loader=$1
fixupobj=$2
shift 2
while [ "$#" -gt 0 ]; do
  src=$1
  dst=$2
  shift 2
  cp "$src" "$dst"
  chmod u+w "$dst"
  "$loader" "$fixupobj" "$dst"
done
""",
            arguments = [args],
            inputs = batch,
            tools = [ctx.file._loader, ctx.file._fixupobj],
            outputs = outputs,
            mnemonic = "CosmopolitanFixObjects",
            use_default_shell_env = True,
        )
        fixed.extend(outputs)

    archive = ctx.actions.declare_file("lib" + ctx.label.name + ".a")
    args = ctx.actions.args()
    args.add("rcsD")
    args.add(archive)

    # GNU BFD uses the first archive member for duplicate symbols. As in the
    # released libcosmo.a, put cxa_personality.o and vga-init.greg.o ahead of
    # the corresponding weak definitions in personality.o and kprintf.greg.o.
    args.add_all(sorted(fixed, key = _archive_priority))
    args.add_all(ctx.files.extra_objects)
    args.use_param_file("@%s")
    ctx.actions.run(
        executable = ctx.attr.archiver[DefaultInfo].files_to_run,
        inputs = fixed + ctx.files.extra_objects,
        arguments = [args],
        outputs = [archive],
        mnemonic = "CosmopolitanArchive",
    )
    return DefaultInfo(files = depset([archive]))

_cosmo_archive = rule(
    implementation = _cosmo_archive_impl,
    attrs = {
        "archiver": attr.label(executable = True, cfg = "exec", mandatory = True),
        "deps": attr.label_list(providers = [CcInfo]),
        "extra_objects": attr.label_list(allow_files = [".o"]),
        "_loader": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = "//runtimes/cosmo:ape_loader",
        ),
        "_fixupobj": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = "@cosmopolitan_sdk//:fixupobj",
        ),
    },
)

_builder = configure_builder_for_runtimes(with_cfg(_cosmo_archive), "stage0")
_builder.set(Label("//toolchain:bootstrap_stage"), "stage1_from_source")
_builder.set(Label("//config:nostdincxx"), True)

# with_cfg may create a separate alias rule on older Bazel versions.
# buildifier: disable=unused-variable
_cosmo_static_library, _cosmo_static_library_internal = _builder.build()

def cosmo_sdk_tool(name, extra_srcs):
    """Builds a Cosmopolitan SDK tool using the selected SDK."""
    cc_binary(
        name = name,
        srcs = ["tool/build/" + name + ".c"] + extra_srcs,
        conlyopts = ["-std=gnu23"],
        copts = [
            "-D_COSMO_SOURCE",
            "-iquote" + native.package_relative_label(":headers").workspace_root,
        ],
        tags = ["manual"],
        target_compatible_with = ["@llvm//constraints/libc:cosmo"],
        visibility = ["//visibility:public"],
        deps = [":headers"],
    )

def cosmo_static_library(name, groups, extra_objects = []):
    """Builds an archive from Cosmopolitan source groups with matching flags."""
    libraries = []
    root = native.package_relative_label(":headers").workspace_root
    common = [
        "-O2",
        "-D_COSMO_SOURCE",
        '-DMODE=\\"opt\\"',
        "-DSYSDEBUG",
        "-fno-pie",
        "-fno-stack-protector",
        "-fno-common",
        "-fno-omit-frame-pointer",
        "-fno-semantic-interposition",
        "-ffunction-sections",
        "-fdata-sections",
        "-nostdlibinc",
        "-isystem" + root + "/libc/isystem",
        "-include",
        root + "/libc/integral/normalize.inc",
        "-iquote" + root,
        "-Wa,-I" + root,
        "-Wno-unknown-pragmas",
        "-Wno-unknown-warning-option",
        "-Qunused-arguments",
    ] + select({
        "@platforms//cpu:x86_64": [
            "-mno-red-zone",
            "-mno-tls-direct-seg-refs",
        ],
        "@platforms//cpu:aarch64": [
            "-ffixed-x18",
            "-ffixed-x28",
            "-fsigned-char",
        ],
    })
    for i, (flags, srcs) in enumerate(groups):
        library = "%s_objects_%d" % (name, i)
        cc_library(
            name = library,
            srcs = srcs,
            copts = common + [flag for flag in flags if not flag.startswith("-std=")],
            conlyopts = ["-std=gnu17" if "-std=gnu17" in flags else "-std=gnu23", "-Wno-pointer-sign"],
            cxxopts = [
                "-std=gnu++23",
                "-nostdinc++",
                "-Wno-narrowing",
                "-I" + root + "/third_party/libcxx",
            ],
            deps = [":headers"],
            features = ["-layering_check", "-use_module_maps"],
            linkstatic = True,
            visibility = ["//visibility:private"],
        )
        libraries.append(":" + library)
    _cosmo_static_library(
        name = name,
        archiver = ":archive_llvm_ar",
        deps = libraries,
        extra_objects = extra_objects,
        visibility = ["//visibility:public"],
    )

def _zip_objects_impl(ctx):
    objects = []
    src_root = ctx.label.workspace_root + "/"
    for src in ctx.files.srcs:
        path = src.path.removeprefix(src_root)
        out = ctx.actions.declare_file("zip/" + path + ".o")
        name = src.basename if path == "libc/runtime/.cosmo" else path
        args = ctx.actions.args()
        args.add(ctx.file._zipobj)
        args.add("-a", ctx.attr.cpu)
        args.add("-N", name)
        args.add("-o", out)
        args.add(src)
        ctx.actions.run(
            executable = ctx.file._loader,
            tools = [ctx.file._zipobj],
            inputs = [src],
            outputs = [out],
            arguments = [args],
            mnemonic = "CosmopolitanZipObject",
        )
        objects.append(out)
    for path in ctx.attr.directories:
        out = ctx.actions.declare_file("zip/" + path + ".o")
        ctx.actions.run_shell(
            command = """
set -eu
directory=$(mktemp -d cosmo-zip.XXXXXXXX)
trap 'rmdir "$directory"' EXIT
chmod 755 "$directory"
"$1" "$2" -a "$3" -N "$4" -o "$5" "$directory"
""",
            arguments = [ctx.file._loader.path, ctx.file._zipobj.path, ctx.attr.cpu, path, out.path],
            tools = [ctx.file._loader, ctx.file._zipobj],
            outputs = [out],
            mnemonic = "CosmopolitanZipDirectory",
            use_default_shell_env = True,
        )
        objects.append(out)
    return DefaultInfo(files = depset(objects))

_zip_objects = rule(
    implementation = _zip_objects_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "cpu": attr.string(mandatory = True),
        "directories": attr.string_list(),
        "_loader": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = "//runtimes/cosmo:ape_loader",
        ),
        "_zipobj": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = "@cosmopolitan_sdk//:bin/zipobj",
        ),
    },
)

def cosmo_zip_assets(srcs):
    """Converts upstream's ZIP assets to target ELF objects."""
    _zip_objects(
        name = "zip_objects",
        cpu = select({
            "@platforms//cpu:aarch64": "aarch64",
            "@platforms//cpu:x86_64": "x86_64",
        }),
        directories = [path for path in srcs if path.endswith("/")],
        srcs = [path for path in srcs if not path.endswith("/")],
    )
