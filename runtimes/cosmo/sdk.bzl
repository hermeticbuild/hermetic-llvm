load("//:http_bsdtar_archive.bzl", "http_bsdtar_archive")

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
            "bin/*-linux-cosmo-ld",
            "*-linux-cosmo/lib/*.a",
            "*-linux-cosmo/lib/*.lds",
            "*-linux-cosmo/lib/ape.o",
            "*-linux-cosmo/lib/crt.o",
        ],
        excludes = ["*-linux-cosmo/lib/*/*"],
    )
    return ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = ["cosmopolitan_sdk"],
        root_module_direct_dev_deps = [],
    )

cosmopolitan = module_extension(
    implementation = _cosmopolitan_impl,
    doc = "Imports the Cosmopolitan headers, runtimes, linkers, and APE tools from the upstream SDK.",
)
