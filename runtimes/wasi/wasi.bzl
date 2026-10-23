"""Rules for the wasi-libc headers, static archives, and startup objects."""

load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@llvm//toolchain/runtimes:cc_runtime_library.bzl", "cc_runtime_stage0_library")
load("@llvm//toolchain/runtimes:cc_runtime_static_library.bzl", "cc_runtime_stage0_static_library")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _wasi_headers_impl(ctx):
    # wasi-libc uses -I for musl's private headers, before the installed public
    # headers searched with -isystem. In particular, src/include/features.h
    # includes ../../include/features.h, so preserve its original source tree.
    includes = [
        ctx.label.workspace_root + "/" + include
        for include in ctx.attr.includes
    ]
    public_dir = ctx.file.public_headers
    headers = depset(ctx.files.hdrs + ([public_dir] if public_dir else []))
    return [
        DefaultInfo(files = headers),
        CcInfo(compilation_context = cc_common.create_compilation_context(
            headers = headers,
            includes = depset(includes),
            system_includes = depset([public_dir.path] if public_dir else []),
        )),
    ]

wasi_headers = rule(
    implementation = _wasi_headers_impl,
    attrs = {
        "hdrs": attr.label_list(allow_files = True),
        "includes": attr.string_list(),
        "public_headers": attr.label(allow_single_file = True),
    },
)

def wasi_static_library(name, deps):
    """Archives stage-0 runtime dependencies under their WASI sysroot filename."""
    cc_runtime_stage0_static_library(
        name = name + "_archive",
        deps = deps,
    )
    copy_file(
        name = name,
        src = name + "_archive",
        out = "lib/lib%s.a" % name,
        allow_symlink = True,
    )

def _wasi_compilation_object_impl(ctx):
    objects = ctx.attr.src[OutputGroupInfo].compilation_outputs.to_list()

    # cc_library may compile both pic and non-pic object outputs. CRT copts
    # explicitly specify -fPIC in both, as in wasi-libc's CMakeLists.txt.
    nonpic = [src for src in objects if not src.basename.endswith(".pic.o")]
    selected = nonpic or objects
    if len(selected) != 1:
        fail("Expected one compiled WASI CRT object, got %s" % selected)
    ctx.actions.symlink(
        output = ctx.outputs.out,
        target_file = selected[0],
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

_wasi_compilation_object = rule(
    implementation = _wasi_compilation_object_impl,
    attrs = {
        "out": attr.output(mandatory = True),
        "src": attr.label(mandatory = True),
    },
)

def wasi_crt_object(name, out, **kwargs):
    """Retains the raw Clang object; wasm-ld -r discards WASI export_name."""
    cc_runtime_stage0_library(
        name = name + "_lib",
        **kwargs
    )
    _wasi_compilation_object(
        name = name,
        src = name + "_lib",
        out = out,
    )
