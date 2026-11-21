"""Stages the Cosmopolitan include tree from the patched source archive."""

load("@bazel_tools//tools/build_defs/repo:cache.bzl", "get_default_canonical_id")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth", "patch")

def _copy_sdk_headers(ctx):
    # Use the released SDK's file names and the patched source's file contents.
    include = ctx.path(ctx.attr.sdk_build_file).dirname.get_child("include")
    directories = [(include, "")]
    for _ in range(10000):
        directory, prefix = directories.pop()
        for entry in directory.readdir(watch = "yes"):
            destination = prefix + entry.basename
            if entry.is_dir:
                directories.append((entry, destination + "/"))
                continue

            # tool/cosmocc/package.sh installs libc/isystem at the include
            # root and libc/integral under libc before copying COSMOCC_HDRS.
            source = destination
            if not ctx.path(source).exists:
                if destination.startswith("libc/"):
                    source = "libc/integral/" + destination.removeprefix("libc/")
                if not ctx.path(source).exists:
                    source = "libc/isystem/" + destination
            ctx.template("include/" + destination, source, executable = False)
        if not directories:
            return
    fail("Cosmopolitan SDK include tree exceeds 10000 directories")

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

    _copy_sdk_headers(ctx)
    ctx.template("BUILD.bazel", ctx.attr.build_file, executable = False)
    return ctx.repo_metadata(reproducible = True)

cosmopolitan_source = repository_rule(
    implementation = _cosmopolitan_source_impl,
    attrs = {
        "build_file": attr.label(allow_single_file = True, mandatory = True),
        "patch_strip": attr.int(),
        "patches": attr.label_list(allow_files = True),
        "sdk_build_file": attr.label(allow_single_file = True, mandatory = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(mandatory = True),
        "urls": attr.string_list(mandatory = True),
    },
    doc = "Fetches and patches the Cosmopolitan source and stages the SDK headers.",
)
