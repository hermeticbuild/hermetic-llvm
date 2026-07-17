load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo", "create_directory_info")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")

# We want to put a source directory into the DefaultInfo but still propagate
# the DirectoryInfo for header inclusion checking and the toolchain's module
# map.
def headers_directory(name, path, visibility = None):
    if path == ".":
        directory(
            name = name + "_directory",
            srcs = native.glob(["**"]),
        )
    else:
        directory(
            name = name + "_files",
            srcs = native.glob([path + "/**"]),
        )

        subdirectory(
            name = name + "_directory",
            path = path,
            parent = name + "_files",
        )

    native.filegroup(
        name = name + "_source_directory",
        srcs = [path],
    )

    _headers_directory(
        name = name,
        directory = name + "_directory",
        source_directory = name + "_source_directory",
        visibility = visibility,
    )

def _headers_directory_impl(ctx):
    return [
        ctx.attr.directory[DirectoryInfo],
        DefaultInfo(
            files = ctx.attr.source_directory[DefaultInfo].files,
        ),
    ]

_headers_directory = rule(
    implementation = _headers_directory_impl,
    attrs = {
        "directory": attr.label(),
        "source_directory": attr.label(),
    },
    cfg = config.none(),
)

def _directory_info_impl(ctx):
    files = ctx.attr.src[DefaultInfo].files.to_list()
    if len(files) != 1 or not files[0].is_directory:
        fail("directory_info requires exactly one directory artifact")
    directory = files[0]
    return [
        create_directory_info(
            entries = {},
            human_readable = str(ctx.label),
            path = directory.path,
            transitive_files = depset([directory]),
        ),
        DefaultInfo(files = depset([directory])),
    ]

directory_info = rule(
    implementation = _directory_info_impl,
    attrs = {"src": attr.label(mandatory = True)},
    provides = [DirectoryInfo],
)
