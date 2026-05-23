load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("//:http_bsdtar_archive.bzl", "http_bsdtar_archive")

GCC_COMMIT = "2bfd402f8569511901ec8fe7628f57471e6d240a"
GCC_SHA256 = "dc033fdfd79caf199113446af6d082004534437b6ebd276f9732815d86cbe723"

# Sparse archive roots required by 3rd_party/gcc/gcc.BUILD.bazel. Before
# trimming or extending this list, check the BUILD file against GCC's
# libstdc++-v3/include/Makefile.am, libsupc++/Makefile.am, and
# src/*/Makefile.am inputs.
_GCC_ARCHIVE_INCLUDES = [
    "gcc/BASE-VER",
    "gcc/DATESTAMP",
    "gcc/ginclude/unwind-arm-common.h",
    "config/acx.m4",
    "config/cet.m4",
    "config/futex.m4",
    "config/gc++filt.m4",
    "config/gthr.m4",
    "config/hwcaps.m4",
    "config/iconv.m4",
    "config/lthostflags.m4",
    "config/multi.m4",
    "config/no-executables.m4",
    "config/tls.m4",
    "config/toolexeclibdir.m4",
    "config/unwind_ipinfo.m4",
    "include/ansidecl.h",
    "include/demangle.h",
    "include/dyn-string.h",
    "include/getopt.h",
    "include/libiberty.h",
    "libgcc/gthr-posix.h",
    "libgcc/gthr-single.h",
    "libgcc/gthr.h",
    "libgcc/config/arm/unwind-arm.h",
    "libgcc/unwind-generic.h",
    "libgcc/unwind-pe.h",
    "libiberty/cp-demangle.c",
    "libiberty/cp-demangle.h",
    "libstdc++-v3/acinclude.m4",
    "libstdc++-v3/config/**",
    "libstdc++-v3/configure.ac",
    "libstdc++-v3/configure.host",
    "libstdc++-v3/crossconfig.m4",
    "libstdc++-v3/linkage.m4",
    "libstdc++-v3/include/**",
    "libstdc++-v3/libsupc++/**",
    "libstdc++-v3/src/**",
]

_from_path = tag_class(
    attrs = {
        "path": attr.string(mandatory = True),
    },
)

def _gcc_impl(module_ctx):
    root_path = None
    dependency_path = None
    for mod in module_ctx.modules:
        for tag in mod.tags.from_path:
            if mod.is_root:
                if root_path != None:
                    fail("Only one root GCC source path override is allowed.")
                root_path = tag.path
            else:
                if dependency_path != None and dependency_path != tag.path:
                    fail("Only one dependency GCC source path override is allowed.")
                dependency_path = tag.path

    path = root_path or dependency_path

    metadata_kwargs = {}

    if path != None:
        new_local_repository(
            name = "gcc",
            build_file = "//3rd_party/gcc:gcc.BUILD.bazel",
            path = path,
        )
    else:
        http_bsdtar_archive(
            name = "gcc",
            build_file = "//3rd_party/gcc:gcc.BUILD.bazel",
            includes = _GCC_ARCHIVE_INCLUDES,
            sha256 = GCC_SHA256,
            strip_prefix = "gcc-{}".format(GCC_COMMIT),
            urls = ["https://github.com/gcc-mirror/gcc/archive/{}.tar.gz".format(GCC_COMMIT)],
        )

        if bazel_features.external_deps.extension_metadata_has_reproducible:
            metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["gcc"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

gcc = module_extension(
    implementation = _gcc_impl,
    tag_classes = {
        "from_path": _from_path,
    },
)
