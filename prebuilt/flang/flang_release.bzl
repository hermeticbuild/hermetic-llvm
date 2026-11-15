"""Private packaging for the qualified Linux x86_64 musl Flang distribution."""

load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")
load("@tar.bzl", "mtree_mutate", "mtree_spec", "tar")
load("//prebuilt:mtree.bzl", "mtree")
load("//tools:defs.bzl", "TOOLCHAIN_BINARIES")

_TRIPLE = "x86_64-unknown-linux-musl"
_LLVM_MAJOR = LLVM_VERSION_MAJOR

def _tree_spec(name, suffix, src, strip_prefix, package_dir):
    mtree_spec(
        name = name + "_" + suffix + "_spec",
        srcs = [src],
        tags = ["manual"],
    )
    mtree_mutate(
        name = name + "_" + suffix + "_mtree",
        mtree = name + "_" + suffix + "_spec",
        strip_prefix = strip_prefix,
        package_dir = package_dir,
        tags = ["manual"],
    )
    return name + "_" + suffix + "_mtree"

def flang_release(name):
    """Assemble the Flang compiler and static target closure for one platform."""
    native.genrule(
        name = name + "_config",
        srcs = ["flang.cfg.in"],
        outs = ["flang.cfg"],
        cmd = "sed 's/@LLVM_MAJOR@/{}/g' $(location flang.cfg.in) > $@".format(_LLVM_MAJOR),
        tags = ["manual"],
    )

    trees = [
        ("modules", ":intrinsic_modules_linux_amd64_musl", "prebuilt/flang/intrinsic_modules_linux_amd64_musl", "lib/clang/{}/finclude/flang/{}".format(_LLVM_MAJOR, _TRIPLE)),
        ("headers", "//runtimes/musl:musl_headers_include_search_directory", "generated/x86_64/includes", "sysroot/usr/include"),
        ("libraries", "//runtimes/musl:musl_library_search_directory", "runtimes/musl/musl_library_search_directory", "sysroot/usr/lib"),
        ("crt", "//runtimes:crt_objects_directory_linux", "runtimes/crt_objects_directory_linux", "sysroot/usr/lib"),
        ("builtins", "//runtimes:resource_directory_default", "runtimes/resource_directory_default", "lib/clang/{}".format(_LLVM_MAJOR)),
        ("clang_headers", "@llvm-project//clang:builtin_headers_files", "clang/lib/Headers", "lib/clang/{}/include".format(_LLVM_MAJOR)),
    ]
    tree_mtrees = [
        _tree_spec(name, suffix, src, strip_prefix, package_dir)
        for suffix, src, strip_prefix, package_dir in trees
    ]

    files = {
        "//prebuilt/flang:flang_stripped": "bin/flang",
        "@llvm-toolchain-minimal-linux-amd64//:bin/llvm": "bin/llvm",
        "//prebuilt/flang:flang.cfg": "bin/flang.cfg",
        "@llvm-project//flang-rt/lib/runtime:flang_rt.runtime": "lib/clang/{}/lib/{}/libflang_rt.runtime.a".format(_LLVM_MAJOR, _TRIPLE),
        "@llvm-project//flang:include/flang/ISO_Fortran_binding.h": "include/ISO_Fortran_binding.h",
        "@llvm-project//flang:LICENSE.TXT": "LICENSE.Flang.txt",
        "@llvm-project//llvm:LICENSE.TXT": "LICENSE.LLVM.txt",
    }
    mtree(
        name = name + "_files_mtree",
        files = files,
        symlinks = {
            "bin/" + binary: "llvm"
            for binary in TOOLCHAIN_BINARIES
            if binary != "flang"
        },
        tags = ["manual"],
    )

    native.genrule(
        name = name + "_mtree",
        srcs = tree_mtrees + [name + "_files_mtree"],
        # mtree directory entries change the BSD tar parser's current path
        # when several independently rooted manifests are concatenated.
        # File entries create their parent directories automatically.
        cmd = "sed '/type=dir/d' $(SRCS) > $@",
        outs = [name + "_spec.mtree"],
        tags = ["manual"],
    )

    tar(
        name = name,
        srcs = files.keys() + [src for _, src, _, _ in trees],
        mtree = name + "_mtree",
        compress = "zstd",
        args = ["--options", "zstd:compression-level=6"],
        tags = ["manual"],
    )
