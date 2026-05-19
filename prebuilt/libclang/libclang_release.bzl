load("@tar.bzl//tar:tar.bzl", "tar")
load("//prebuilt:mtree.bzl", "mtree")

# Builds an opt-in tarball containing only libclang for downstream
# bindgen / clang-sys consumers wiring LIBCLANG_PATH. Kept separate from
# the main llvm_release tarball so consumers who don't need libclang pay
# nothing for it (the http_archive only fetches when a label inside is
# referenced).
#
# v1 scope: Linux only. Upstream cc_plugin_library generates
# per-platform single-file targets (:libclang.so, :libclang.dylib,
# :libclang.dll); macOS / Windows can be added once tested on those execs.
def libclang_release(name):
    files = {
        "@llvm-project//clang:libclang.so": "lib/libclang.so",
    }

    mtree(
        name = name + "_mtree",
        files = files,
        tags = ["manual"],
    )

    tar(
        name = name,
        srcs = files.keys(),
        args = [
            "--options",
            "zstd:compression-level=22",
        ],
        compress = "zstd",
        mtree = name + "_mtree",
        tags = ["manual"],
    )
