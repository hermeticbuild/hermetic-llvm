load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")

_from_path = tag_class(
    attrs = {
        "path": attr.string(mandatory = True),
    },
)

def _gcc_impl(module_ctx):
    path = None
    for mod in module_ctx.modules:
        for tag in mod.tags.from_path:
            if path != None:
                fail("Only one GCC source path override is allowed.")
            path = tag.path

    if path == None:
        module_file = str(module_ctx.path(Label("//:MODULE.bazel")))
        module_root = module_file.removesuffix("/MODULE.bazel")
        path = module_root + "/../gcc"

    new_local_repository(
        name = "gcc",
        build_file = "//3rd_party/gcc:gcc.BUILD.bazel",
        path = path,
    )

gcc = module_extension(
    implementation = _gcc_impl,
    tag_classes = {
        "from_path": _from_path,
    },
)
