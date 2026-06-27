load("@bazel_tools//tools/build_defs/repo:cache.bzl", "DEFAULT_CANONICAL_ID_ENV")
load("@bazel_tools//tools/build_defs/repo:git_worker.bzl", "git_repo")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "patch")
load(
    ":llvm_project_common.bzl",
    "copy_overlay",
    "symlink_source_and_overlay",
    "write_llvm_project_files",
)

def _symlink_git_strip_prefix(rctx, source_root):
    entries = source_root.readdir()
    for entry in entries:
        rctx.symlink(entry, entry.basename)
    return entries

def _remove_git_strip_prefix_symlinks(rctx, entries):
    for entry in entries:
        path = rctx.path(entry.basename)
        if path.exists:
            rctx.delete(path)

def _llvm_project_from_git_impl(rctx):
    if ((rctx.attr.tag and rctx.attr.commit) or
        (rctx.attr.tag and rctx.attr.branch) or
        (rctx.attr.commit and rctx.attr.branch)):
        fail("At most one of commit, tag, or branch may be provided")
    source_root = rctx.path(".")
    if rctx.attr.strip_prefix:
        source_root = source_root.get_child(".tmp_git_root")

    git_repo(rctx, str(source_root))
    if rctx.attr.strip_prefix:
        source_root = source_root.get_child(rctx.attr.strip_prefix)
        if not source_root.exists:
            fail("strip_prefix at {} does not exist in repo".format(rctx.attr.strip_prefix))
        strip_prefix_entries = _symlink_git_strip_prefix(rctx, source_root)

    patch(rctx)
    if rctx.attr.strip_prefix:
        _remove_git_strip_prefix_symlinks(rctx, strip_prefix_entries)
        symlink_source_and_overlay(rctx, source_root)
        rctx.delete(rctx.path(".tmp_git_root/.git"))
    else:
        copy_overlay(rctx, source_root)
        rctx.delete(rctx.path(".git"))
    write_llvm_project_files(rctx)

    return rctx.repo_metadata(reproducible = False)

llvm_project_from_git = repository_rule(
    implementation = _llvm_project_from_git_impl,
    attrs = {
        "remote": attr.string(mandatory = True),
        "commit": attr.string(),
        "tag": attr.string(),
        "branch": attr.string(),
        "shallow_since": attr.string(),
        "init_submodules": attr.bool(default = False),
        "recursive_init_submodules": attr.bool(default = False),
        "strip_prefix": attr.string(),
        "patches": attr.label_list(default = []),
        "patch_args": attr.string_list(default = []),
        "patch_strip": attr.int(default = 0),
        "patch_cmds": attr.string_list(default = []),
        "patch_cmds_win": attr.string_list(default = []),
        "patch_tool": attr.string(),
        "remote_module_file_urls": attr.string_list(default = []),
        "remote_module_file_integrity": attr.string(),
        "remote_patches": attr.string_dict(default = {}),
        "remote_patch_strip": attr.int(default = 0),
        "verbose": attr.bool(default = False),
        "targets": attr.string_list(mandatory = True),
    },
    environ = [DEFAULT_CANONICAL_ID_ENV],
)
