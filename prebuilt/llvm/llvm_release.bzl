load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")
load("@tar.bzl", "mtree_mutate", "mtree_spec", "tar")
load("//prebuilt:mtree.bzl", "mtree")
load("//tools:defs.bzl", "TOOLCHAIN_BINARIES")

def _exec_configured_file_impl(ctx):
    return [DefaultInfo(files = depset([ctx.file.src]))]

exec_configured_file = rule(
    implementation = _exec_configured_file_impl,
    doc = "Builds src in the exec configuration of the platform selected by exec_compatible_with.",
    attrs = {
        "src": attr.label(
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
    },
)

def llvm_release(name, bin_suffix = "", target_compatible_with = [], llvm = "//toolchain/bootstrap/stage3:llvm", tags = ["manual"]):
    """Packages an LLVM binary as a minimal toolchain archive.

    Args:
        name: Name of the archive target.
        bin_suffix: Suffix of the binaries, ".exe" on Windows.
        target_compatible_with: Constraints of the platforms the archive is for.
        llvm: The multicall LLVM binary to package.
        tags: Tags of the archive target.
    """
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
        llvm: "bin/llvm" + bin_suffix,
        "@llvm-project//compiler-rt:asan_ignorelist": "lib/clang/{llvm_major}/share/asan_ignorelist.txt",
        "@llvm-project//compiler-rt:msan_ignorelist": "lib/clang/{llvm_major}/share/msan_ignorelist.txt",
    }

    mtree(
        name = name + "_bins_mtree",
        files = bin_files,
        symlinks = {
            "bin/" + binary + bin_suffix: "llvm" + bin_suffix
            for binary in ["clang-{llvm_major}"] + TOOLCHAIN_BINARIES
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
        tags = tags,
        target_compatible_with = target_compatible_with,
    )
