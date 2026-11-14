"""
Helper functions for defining targets.
"""

load("@rules_cc//cc:cc_library.bzl", "cc_library")

def atomic_helper_cc_library(name, pat, size, model):
    unique_filename = "lse_{}_{}_{}".format(pat, size, model)

    # cc_library will always produce an archive file containing lse.o.
    # Because those end up in a static library, cc_static_library will complain
    # that the archive has lse.o specified multiple times. The renamed copies
    # are written when llvm-project is fetched (see lse_variants.bzl).
    cc_library(
        name = name,
        srcs = ["lib/builtins/aarch64/{}.S".format(unique_filename)],
        copts = select({
            # The clang-cl hermetic compilation policy already supplies both
            # options with its required /clang: spelling.
            ":windows_msvc": [],
            "//conditions:default": [
                # Normally, we would pass -nostdinc, but since we pass -nostdlibinc
                # from the runtimes toolchain args regardless, having them both causes a
                # warning about -nostdlibinc being ignored, so we duplicate the
                # -nostdlibinc and add -nobuiltininc to avoid the warning.
                #
                # -nostdinc = -nostdlibinc -nobuiltininc
                "-nostdlibinc",
                "-nobuiltininc",
            ],
        }),
        local_defines = [
            "L_{}".format(pat),
            "SIZE={}".format(size),
            "MODEL={}".format(model),
        ],
        hdrs = [
            "lib/builtins/assembly.h",
        ],
        includes = ["lib/builtins"],
    )
    return name
