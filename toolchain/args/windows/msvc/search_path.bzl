"""Joins library directories into a single `cc_args` format value."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")

def _directory_path(target):
    if DirectoryInfo in target:
        return target[DirectoryInfo].path
    files = target[DefaultInfo].files.to_list()
    if not files:
        # Empty targets such as //runtimes:none select a directory away.
        return None
    if len(files) != 1:
        fail("%s should be either a directory or a single file." % target.label)
    return files[0].path

def _search_path_impl(ctx):
    paths = []
    for directory in ctx.attr.directories:
        path = _directory_path(directory)
        if path != None and path not in paths:
            paths.append(path)
    return [
        DefaultInfo(files = depset(transitive = [
            directory[DefaultInfo].files
            for directory in ctx.attr.directories
        ])),
        # cc_args accepts only one format variable per string, so expose the
        # joined list as a single string value.
        BuildSettingInfo(value = ";".join(paths)),
    ]

search_path = rule(
    implementation = _search_path_impl,
    doc = "Joins directory paths with `;`, as in the MSVC `LIB` variable.",
    attrs = {
        "directories": attr.label_list(mandatory = True),
    },
)
