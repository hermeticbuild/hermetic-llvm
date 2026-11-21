"""Pinned type contracts shared by the root and example workspaces."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_SKYLIB_STUBS_COMMIT = "d59fe05713540581d30020697a91f0c7850d2ace"

def _sty_stubs_impl(_module_ctx):
    # type: (...) -> None
    http_archive(
        name = "bazel_skylib_stubs",
        build_file_content = 'exports_files(["stubs.toml"])',
        sha256 = "b09e17231210f90057e049b3b2c2ddba30682cc5d57825ca0481258ead0f8353",
        strip_prefix = "rules_cc-{}/stubs/bazel_skylib".format(_SKYLIB_STUBS_COMMIT),
        urls = ["https://github.com/bazelbuild/rules_cc/archive/{}.tar.gz".format(_SKYLIB_STUBS_COMMIT)],
    )

sty_stubs = module_extension(implementation = _sty_stubs_impl)
