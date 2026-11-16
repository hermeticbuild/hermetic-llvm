load("@tar.bzl", "tar")
load("//prebuilt:mtree.bzl", "mtree")

def flang_release(name, bin_suffix = "", target_compatible_with = []):
    files = {
        ":flang_lto": "bin/flang" + bin_suffix,
        "@llvm-project//flang:LICENSE.TXT": "LICENSE.Flang.txt",
        "@llvm-project//llvm:LICENSE.TXT": "LICENSE.LLVM.txt",
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
        target_compatible_with = target_compatible_with,
    )
