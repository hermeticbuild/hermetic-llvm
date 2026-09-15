"""Merge a compiler's include/share directories with explicit resource trees."""

load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")

def _workspace_path(file):
    path = file.short_path
    return path.split("/", 2)[2] if path.startswith("../") else path

def _merged_resource_directory_impl(ctx):
    parent = ctx.file.parent
    parent_path = _workspace_path(parent)
    src_paths = [_workspace_path(src) for src in ctx.files.srcs]
    out = ctx.actions.declare_directory(ctx.label.name)
    copy_to_directory_bin_action(
        ctx,
        name = ctx.label.name,
        copy_to_directory_bin = ctx.toolchains["@bazel_lib//lib:copy_to_directory_toolchain_type"].copy_to_directory_info.bin,
        dst = out,
        files = [parent] + ctx.files.srcs,
        root_paths = [],
        include_external_repositories = ["**"],
        # Never import a prebuilt compiler's host runtime libraries.
        include_srcs_patterns = [
            parent_path + "/include/**",
            parent_path + "/share/**",
        ] + [path + "/**" for path in src_paths],
        replace_prefixes = {parent_path: ""} | {path: "" for path in src_paths},
    )
    return DefaultInfo(files = depset([out]))

merged_resource_directory = rule(
    doc = "Inherit only include/ and share/ from parent, then merge srcs at the resource root.",
    implementation = _merged_resource_directory_impl,
    attrs = {
        # Bound by the same declaration that selects the executable, not by
        # resolving a C++ toolchain from inside the runtime dependency graph.
        "parent": attr.label(
            doc = "The resource directory belonging to the selected compiler; its lib/ is excluded.",
            mandatory = True,
            allow_single_file = True,
            cfg = "exec",
        ),
        "srcs": attr.label_list(
            doc = "Resource directory trees to merge, configured for the target platform.",
            mandatory = True,
            allow_files = True,
        ),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
