load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")

_from_path = tag_class(
    attrs = {
        "path": attr.string(mandatory = True),
    },
)

def _gcc_impl(module_ctx):
    root_path = None
    dependency_path = None
    for mod in module_ctx.modules:
        for tag in mod.tags.from_path:
            if mod.is_root:
                if root_path != None:
                    fail("Only one root GCC source path override is allowed.")
                root_path = tag.path
            else:
                if dependency_path != None and dependency_path != tag.path:
                    fail("Only one dependency GCC source path override is allowed.")
                dependency_path = tag.path

    path = root_path or dependency_path

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
