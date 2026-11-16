load("//:http_bsdtar_archive.bzl", "http_bsdtar_archive")
load("//runtimes/cosmo/source:headers.bzl", "cosmopolitan_source")

_COSMOPOLITAN_VERSION = "4.0.2"

def _cosmopolitan_impl(ctx):
    http_bsdtar_archive(
        name = "cosmopolitan_sdk",
        build_file = Label("//runtimes/cosmo:sdk.BUILD.bazel"),
        sha256 = "85b8c37a406d862e656ad4ec14be9f6ce474c1b436b9615e91a55208aced3f44",
        urls = ["https://github.com/jart/cosmopolitan/releases/download/{0}/cosmocc-{0}.zip".format(_COSMOPOLITAN_VERSION)],
        includes = [
            "LICENSE*",
            "include/*",
            "bin/ape-aarch64.elf",
            "bin/ape-m1.c",
            "bin/ape-x86_64.elf",
            "bin/ape-x86_64.macho",
            "bin/apelink",
            "bin/fixupobj",
            "bin/pecheck",
            "bin/zipobj",
            "bin/*-linux-cosmo-ld",
            "*-linux-cosmo/lib/*.a",
            "*-linux-cosmo/lib/*.lds",
            "*-linux-cosmo/lib/ape.o",
            "*-linux-cosmo/lib/crt.o",
        ],
        excludes = ["*-linux-cosmo/lib/*/*"],
    )
    cosmopolitan_source(
        name = "cosmopolitan_source",
        build_file = Label("//runtimes/cosmo/source:cosmopolitan.BUILD.bazel"),
        sdk_build_file = "@cosmopolitan_sdk//:BUILD.bazel",
        sha256 = "e466106b18064e0c996ef64d261133af867bccd921ad14e54975d89aa17a8717",
        strip_prefix = "cosmopolitan-" + _COSMOPOLITAN_VERSION,
        urls = ["https://github.com/jart/cosmopolitan/releases/download/{0}/cosmopolitan-{0}.tar.gz".format(_COSMOPOLITAN_VERSION)],
        patches = [
            "//runtimes/cosmo/source/patches:musl-errno-runtime-cases.patch",
            "//runtimes/cosmo/source/patches:nsync-atomic-pointer-cast.patch",
            "//runtimes/cosmo/source/patches:musl-lookup-name-errno-runtime.patch",
            "//runtimes/cosmo/source/patches:musl-getnameinfo-af-constants.patch",
            "//runtimes/cosmo/source/patches:arm64-clang-compat.patch",
            "//runtimes/cosmo/source/patches:aarch64-fenv.patch",
            "//runtimes/cosmo/source/patches:clang-demangle.patch",
            "//runtimes/cosmo/source/patches:arm64-build-fixes.patch",
            "//runtimes/cosmo/source/patches:pthread-setjmp.patch",
            "//runtimes/cosmo/source/patches:rdseed-guard-nonx86.patch",
            "//runtimes/cosmo/source/patches:rdrand-guard-nonx86.patch",
            "//runtimes/cosmo/source/patches:aarch64-syscall-tls.patch",
            "//runtimes/cosmo/source/patches:dlmalloc-atomic-heap-pointers.patch",
            "//runtimes/cosmo/source/patches:errno-register-convention.patch",
            "//runtimes/cosmo/source/patches:clang-resource-intrinsics.patch",
            "//runtimes/cosmo/source/patches:clang-builtins-and-assembly.patch",
            "//runtimes/cosmo/source/patches:ctl-new-aliases.patch",
            "//runtimes/cosmo/source/patches:openmp-runtime-signals.patch",
            "//runtimes/cosmo/source/patches:aarch64-nt-import-binding.patch",
        ],
        patch_strip = 1,
    )
    return ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = ["cosmopolitan_sdk", "cosmopolitan_source"],
        root_module_direct_dev_deps = [],
    )

cosmopolitan = module_extension(
    implementation = _cosmopolitan_impl,
    doc = "Imports the Cosmopolitan release SDK and sources for the Bazel SDK build.",
)
