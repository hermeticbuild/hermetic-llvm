load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")
load("@tar.bzl", "mtree_mutate", "mtree_spec", "tar")
load("//prebuilt:mtree.bzl", "mtree")
load("//tools:defs.bzl", "TOOLCHAIN_BINARIES")

def llvm_release(
        name,
        bin_suffix = "",
        target_compatible_with = [],
        binary = "//toolchain/bootstrap/stage3:llvm",
        binary_name = None):
    binary_name = binary_name or "llvm" + bin_suffix
    mtree_spec(
        name = name + "_builtin_headers_mtree_",
        srcs = [
            "@llvm-project//clang:builtin_headers_files",
        ],
        tags = ["manual"],
    )

    mtree_mutate(
        name = name + "_builtin_headers_mtree",
        mtree = name + "_builtin_headers_mtree_",
        strip_prefix = "clang/lib/Headers",
        package_dir = "lib/clang/{}/include".format(LLVM_VERSION_MAJOR),
        tags = ["manual"],
    )

    bin_files = {
        binary: "bin/" + binary_name,
        "@llvm-project//compiler-rt:asan_ignorelist": "lib/clang/{llvm_major}/share/asan_ignorelist.txt",
        "@llvm-project//compiler-rt:msan_ignorelist": "lib/clang/{llvm_major}/share/msan_ignorelist.txt",
    }

    mtree(
        name = name + "_bins_mtree",
        files = bin_files,
        symlinks = {
            "bin/" + alias + bin_suffix: binary_name
            for alias in ["clang-{llvm_major}"] + TOOLCHAIN_BINARIES
        },
        format = {
            "llvm_major": LLVM_VERSION_MAJOR,
        },
        tags = ["manual"],
    )

    native.genrule(
        name = name + "_mtree",
        srcs = [
            name + "_bins_mtree",
            name + "_builtin_headers_mtree",
        ],
        cmd = """\
            cat $(SRCS) > $(@)
        """,
        outs = [
            name + "_mtree_spec.mtree",
        ],
        tags = ["manual"],
    )

    tar(
        name = name,
        srcs = bin_files.keys() + [
            "@llvm-project//clang:builtin_headers_files",
        ],
        args = [
            "--options",
            "zstd:compression-level=22",
        ],
        compress = "zstd",
        mtree = name + "_mtree",
        tags = ["manual"],
        target_compatible_with = target_compatible_with,
    )
