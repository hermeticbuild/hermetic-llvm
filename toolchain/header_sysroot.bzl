"""Assemble target headers in the layout understood by the Clang driver."""

load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo", "create_directory_info")

def _header_sysroot_impl(ctx):
    groups = {}
    for src, destination in ctx.attr.directories.items():
        if destination not in groups:
            groups[destination] = struct(files = [], prefixes = {})
        group = groups[destination]
        source_files = src[DefaultInfo].files.to_list()
        if DirectoryInfo in src:
            root = src[DirectoryInfo].path
        elif len(source_files) == 1 and source_files[0].is_directory:
            root = source_files[0].path
        else:
            fail("Expected DirectoryInfo or one tree artifact: %s" % src.label)
        for file in source_files:
            if file.path != root and not file.path.startswith(root + "/"):
                fail("Header %s is outside %s" % (file.path, root))
            path = file.short_path
            if path.startswith("../"):
                path = path.split("/", 2)[2]
            relative = file.path[len(root):].lstrip("/")
            group.prefixes[path] = relative
            group.files.append(file)
    outputs = []
    root = None

    # Separate destinations need separate actions: copy_to_directory strips
    # repository names, so @kernel_headers//:include and @glibc//:include
    # otherwise share the same prefix even though their destinations differ.
    for destination, group in groups.items():
        out = ctx.actions.declare_directory(ctx.label.name + "/" + destination)
        root = out.path[:-len(destination) - 1]
        outputs.append(out)
        copy_to_directory_bin_action(
            ctx,
            name = ctx.label.name + "/" + destination,
            copy_to_directory_bin = ctx.toolchains["@bazel_lib//lib:copy_to_directory_toolchain_type"].copy_to_directory_info.bin,
            dst = out,
            files = group.files,
            root_paths = [],
            include_external_repositories = ["**"],
            replace_prefixes = group.prefixes,
            allow_overwrites = True,
        )
    return [
        DefaultInfo(files = depset(outputs)),
        create_directory_info(
            entries = {},
            human_readable = str(ctx.label),
            path = root,
            transitive_files = depset(outputs),
        ),
    ]

header_sysroot = rule(
    implementation = _header_sysroot_impl,
    attrs = {
        "directories": attr.label_keyed_string_dict(
            doc = "Header directories mapped to sysroot-relative paths; later entries win collisions.",
            mandatory = True,
        ),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
