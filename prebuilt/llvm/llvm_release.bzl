load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@bazel_lib//lib:transitions.bzl", "platform_transition_filegroup")
load("@llvm_config//:version.bzl", "LLVM_VERSION_MAJOR")
load("@tar.bzl", "mtree_mutate", "mtree_spec", "tar")
load("//prebuilt:mtree.bzl", "mtree")
load("//toolchain/bootstrap/bolt:bolt.bzl", "llvm_bolt_binary")
load("//tools:defs.bzl", "TOOLCHAIN_BINARIES")

def _release_llvm_binary(name):
    for cpu in ["aarch64", "x86_64"]:
        bolt_name = name + "_linux_" + cpu + "_bolt"
        llvm_bolt_binary(
            name = bolt_name,
            binary = "//toolchain/bootstrap/stage3:llvm",
            exec_compatible_with = [
                "@platforms//cpu:" + cpu,
                "@platforms//os:linux",
            ],
            target_compatible_with = [
                "@platforms//cpu:" + cpu,
                "@platforms//os:linux",
            ],
        )

        platform_transition_filegroup(
            name = name + "_linux_" + cpu,
            srcs = [":" + bolt_name],
            target_platform = "//platforms:linux_%s_musl" % ({
                "aarch64": "arm64",
                "x86_64": "amd64",
            }[cpu]),
        )

    copy_file(
        name = name,
        src = select({
            "//platforms/config:linux_aarch64": ":" + name + "_linux_aarch64",
            "//platforms/config:linux_x86_64": ":" + name + "_linux_x86_64",
            "//conditions:default": "//toolchain/bootstrap/stage3:llvm",
        }),
        out = name + ".bin",
        is_executable = True,
    )

def llvm_release(name, bin_suffix = "", bolt = True):
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

    llvm_binary = "//toolchain/bootstrap/stage3:llvm"
    if bolt:
        llvm_binary = ":" + name + "_binary"
        _release_llvm_binary(name + "_binary")

    bin_files = {
        llvm_binary: "bin/llvm" + bin_suffix,
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
        tags = ["manual"],
    )
