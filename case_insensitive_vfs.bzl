"""Generates a case-insensitive Clang VFS view of declared directory inputs."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")

def _add_root(args, directory):
    # A directory_info wraps a single tree artifact, which is passed as a File
    # so that path mapping applies to it.
    if not directory.entries:
        files = directory.transitive_files.to_list()
        if len(files) == 1 and files[0].is_directory:
            args.add_all("-root", files, expand_directories = False)
            return
    args.add("-root", directory.path)

def _case_insensitive_vfs_overlay_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".yaml")
    args = ctx.actions.args()
    args.add("-output", output)
    inputs = []
    for directory_target in ctx.attr.roots:
        directory = directory_target[DirectoryInfo]
        _add_root(args, directory)
        inputs.append(directory.transitive_files)

    # The overlay contains the paths of its roots. Supports path mapping, but
    # doesn't opt into it since the decision needs to be in sync with whether
    # compilation actions are opted in.
    ctx.actions.run(
        executable = ctx.executable._generator,
        arguments = [args],
        inputs = depset(transitive = inputs),
        outputs = [output],
        mnemonic = "CaseInsensitiveVFS",
        progress_message = "Generating case-insensitive VFS %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

case_insensitive_vfs_overlay = rule(
    implementation = _case_insensitive_vfs_overlay_impl,
    attrs = {
        "roots": attr.label_list(providers = [DirectoryInfo]),
        "_generator": attr.label(
            allow_single_file = True,
            default = "//tools/case_insensitive_vfs",
            cfg = "exec",
            executable = True,
        ),
    },
)
