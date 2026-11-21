load("@bazel_lib//lib:repo_utils.bzl", "repo_utils")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth")

def _resolve_file_symlinks(rctx, root):
    pending = [rctx.path(root)]
    for _ in range(1000000):
        if not pending:
            break
        for entry in pending.pop().readdir():
            real = entry.realpath
            if real != entry:
                if real.is_dir:
                    continue
                content = rctx.read(real)
                rctx.delete(entry)
                rctx.file(entry, content)
            elif entry.is_dir:
                pending.append(entry)

def _http_pkg_archive_impl(rctx):
    rctx.download(
        url = rctx.attr.urls,
        output = ".downloaded.pkg",
        sha256 = rctx.attr.sha256,
        canonical_id = " ".join(rctx.attr.urls),
        auth = get_auth(rctx, rctx.attr.urls),
    )

    strip_prefix = ""
    if rctx.attr.strip_prefix:
        strip_prefix = rctx.attr.strip_prefix

    args = []

    for include in rctx.attr.includes:
        args.extend(["--include", strip_prefix + "/" + include])

    for exclude in rctx.attr.excludes:
        args.extend(["--exclude", strip_prefix + "/" + exclude])

    if strip_prefix:
        args.extend(["--strip-components", str(len(strip_prefix.split("/")))])

    args.extend(["--expand-full", ".downloaded.pkg", rctx.attr.dst])

    host_pkgutil = Label("@toolchain-extra-prebuilts-%s//:bin/pkgutil" % (repo_utils.platform(rctx).replace("_", "-")))
    res = rctx.execute([rctx.path(host_pkgutil)] + args)
    if res.return_code != 0:
        fail("Failed to extract package: {}".format(res.stderr))

    rctx.delete(".downloaded.pkg")

    _resolve_file_symlinks(rctx, rctx.attr.dst)

    for file, label in rctx.attr.files.items():
        rctx.file(file, rctx.read(label))

    return rctx.repo_metadata(reproducible = True)

http_pkg_archive = repository_rule(
    _http_pkg_archive_impl,
    attrs = {
        "urls": attr.string_list(mandatory = True),
        "sha256": attr.string(mandatory = True),
        "dst": attr.string(mandatory = True),
        "includes": attr.string_list(),
        "excludes": attr.string_list(),
        "strip_prefix": attr.string(),
        "files": attr.string_keyed_label_dict(),
    },
)
