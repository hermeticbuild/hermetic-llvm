load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
load("@rules_cc//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")
load("@with_cfg.bzl", "with_cfg")

def _configure_libstdcxx_runtime_builder(builder, linkmode = None):
    builder.set("copt", [])
    builder.set("cxxopt", [])
    builder.set("linkopt", [])
    builder.set("host_copt", [])
    builder.set("host_cxxopt", [])
    builder.set("host_linkopt", [])

    builder.set(Label("//toolchain:cxxstdlib_mode"), "disabled")

    if linkmode != None:
        builder.set(Label("//runtimes:linkmode"), linkmode)

    for sanitizer in [
        "//config:ubsan",
        "//config:cfi",
        "//config:msan",
        "//config:dfsan",
        "//config:nsan",
        "//config:safestack",
        "//config:rtsan",
        "//config:tysan",
        "//config:tsan",
        "//config:asan",
        "//config:lsan",
        "//config:xray",
        "//config:fuzzer",
        "//config:profile",
        "//config:host_ubsan",
        "//config:host_cfi",
        "//config:host_msan",
        "//config:host_dfsan",
        "//config:host_nsan",
        "//config:host_safestack",
        "//config:host_rtsan",
        "//config:host_tysan",
        "//config:host_tsan",
        "//config:host_asan",
        "//config:host_lsan",
        "//config:host_xray",
        "//config:host_fuzzer",
        "//config:host_profile",
    ]:
        builder.set(Label(sanitizer), False)

    return builder

_library_builder = _configure_libstdcxx_runtime_builder(with_cfg(cc_library))
libstdcxx_runtime_cc_library, _libstdcxx_runtime_cc_library_internal = _library_builder.build()

_shared_library_builder = _configure_libstdcxx_runtime_builder(with_cfg(
    cc_shared_library,
    extra_providers = [CcSharedLibraryInfo],
), "dynamic")
libstdcxx_runtime_cc_shared_library, _libstdcxx_runtime_cc_shared_library_internal = _shared_library_builder.build()

_binary_builder = _configure_libstdcxx_runtime_builder(with_cfg(cc_binary))
libstdcxx_runtime_cc_binary, _libstdcxx_runtime_cc_binary_internal = _binary_builder.build()
