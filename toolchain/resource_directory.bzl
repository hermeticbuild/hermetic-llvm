"""Compose a link resource directory without coupling compiles to runtimes."""

load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")

def _workspace_path(file):
    path = file.short_path
    return path.split("/", 2)[2] if path.startswith("../") else path

def _resource_directory_impl(ctx):
    compiler = ctx.file.compiler_resources
    runtimes = ctx.file.runtimes
    compiler_path = _workspace_path(compiler)
    runtimes_path = _workspace_path(runtimes)
    out = ctx.actions.declare_directory(ctx.label.name)
    copy_to_directory_bin_action(
        ctx,
        name = ctx.label.name,
        copy_to_directory_bin = ctx.toolchains["@bazel_lib//lib:copy_to_directory_toolchain_type"].copy_to_directory_info.bin,
        dst = out,
        files = [compiler, runtimes],
        root_paths = [],
        include_external_repositories = ["**"],
        # Never import a prebuilt compiler's host runtime libraries.
        include_srcs_patterns = [
            compiler_path + "/include/**",
            compiler_path + "/share/**",
            runtimes_path + "/**",
        ],
        replace_prefixes = {compiler_path: "", runtimes_path: ""},
    )
    return DefaultInfo(files = depset([out]))

resource_directory = rule(
    implementation = _resource_directory_impl,
    attrs = {
        # Bound by the same declaration that selects the executable, not by
        # resolving a C++ toolchain from inside the runtime dependency graph.
        "compiler_resources": attr.label(mandatory = True, allow_single_file = True, cfg = "exec"),
        "runtimes": attr.label(default = "//runtimes:resource_directory", allow_single_file = True),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
