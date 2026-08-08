load(
    ":llvm_project_common.bzl",
    "LLVM_PROJECT_OVERLAY",
    "symlink_source_and_overlay",
    "write_llvm_project_files",
)

def _llvm_project_from_path_impl(rctx):
    source_root = rctx.workspace_root.get_child(rctx.attr.path)
    overlay_root = source_root.get_child(LLVM_PROJECT_OVERLAY)
    if not overlay_root.exists:
        fail("LLVM source path {} does not contain {}".format(source_root, LLVM_PROJECT_OVERLAY))

    symlink_source_and_overlay(rctx, source_root)
    write_llvm_project_files(rctx)
    return rctx.repo_metadata(reproducible = False)

llvm_project_from_path = repository_rule(
    implementation = _llvm_project_from_path_impl,
    attrs = {
        "path": attr.string(mandatory = True),
        "targets": attr.string_list(mandatory = True),
    },
    local = True,
)
