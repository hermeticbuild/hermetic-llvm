"""Stages the Cosmopolitan include tree from the patched source archive."""

load("@bazel_tools//tools/build_defs/repo:cache.bzl", "get_default_canonical_id")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth", "patch")
load("@llvm//:directory.bzl", "headers_directory")

def _cosmopolitan_source_impl(ctx):
    urls = ctx.attr.urls
    ctx.download_and_extract(
        url = urls,
        sha256 = ctx.attr.sha256,
        strip_prefix = ctx.attr.strip_prefix,
        auth = get_auth(ctx, urls),
        canonical_id = get_default_canonical_id(ctx, urls),
    )
    patch(ctx)

    for line in ctx.read(ctx.attr._sdk_headers).splitlines():
        if not line or line.startswith("#"):
            continue
        paths = line.split(" ")
        source = paths[0]
        destination = paths[-1]

        # Copy bytes so the repository can be cached independently of its
        # location and the include tree behaves like the released SDK.
        ctx.template("include/" + destination, source, executable = False)

    ctx.template("BUILD.bazel", ctx.attr.build_file, executable = False)
    return ctx.repo_metadata(reproducible = True)

cosmopolitan_source = repository_rule(
    implementation = _cosmopolitan_source_impl,
    attrs = {
        "build_file": attr.label(allow_single_file = True, mandatory = True),
        "patch_strip": attr.int(),
        "patches": attr.label_list(allow_files = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(mandatory = True),
        "urls": attr.string_list(mandatory = True),
        "_sdk_headers": attr.label(default = Label(":sdk_headers.txt"), allow_single_file = True),
    },
    doc = "Fetches and patches the Cosmopolitan source and stages the SDK headers.",
)

def cosmopolitan_sdk_headers():
    """Exports the same DirectoryInfo roots as the released SDK."""
    headers_directory(
        name = "c_headers",
        path = "include",
        visibility = ["//visibility:public"],
    )
    headers_directory(
        name = "cxx_headers",
        path = "include/third_party/libcxx",
        visibility = ["//visibility:public"],
    )
