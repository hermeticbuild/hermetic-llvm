load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo", "create_directory_info")

def _files_directory_info(ctx):
    # Header inclusion checking and module maps only need the path and the files. Skylib's
    # directory rule would retain a DirectoryInfo with a dict and four closures per subdirectory,
    # which adds up to megabytes for SDKs.
    roots = {f.root.path: None for f in ctx.files.srcs}
    if len(roots) > 1:
        fail("{} mixes source and generated files".format(ctx.label))
    root = list(roots)[0] if roots else ""
    return create_directory_info(
        entries = {},
        human_readable = str(ctx.label),
        path = paths.normalize(paths.join(root, ctx.label.workspace_root, ctx.label.package, ctx.attr.path)),
        transitive_files = depset(ctx.files.srcs),
    )

def _files_directory_impl(ctx):
    directory_info = _files_directory_info(ctx)
    return [
        directory_info,
        DefaultInfo(files = directory_info.transitive_files),
    ]

files_directory = rule(
    implementation = _files_directory_impl,
    doc = "Provides a DirectoryInfo for the directory `path` that contains `srcs`, without its entries.",
    attrs = {
        "path": attr.string(default = "."),
        "srcs": attr.label_list(allow_files = True),
    },
    provides = [DirectoryInfo],
)

# We want to put a source directory into the DefaultInfo but still propagate
# the DirectoryInfo for header inclusion checking and the toolchain's module
# map.
def headers_directory(name, path, visibility = None):
    native.filegroup(
        name = name + "_source_directory",
        srcs = [path],
    )

    _headers_directory(
        name = name,
        srcs = native.glob(["**"] if path == "." else [path + "/**"]),
        path = path,
        source_directory = name + "_source_directory",
        visibility = visibility,
    )

def _headers_directory_impl(ctx):
    return [
        _files_directory_info(ctx),
        DefaultInfo(
            files = ctx.attr.source_directory[DefaultInfo].files,
        ),
    ]

_headers_directory = rule(
    implementation = _headers_directory_impl,
    attrs = {
        "path": attr.string(mandatory = True),
        "source_directory": attr.label(mandatory = True),
        "srcs": attr.label_list(allow_files = True),
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
