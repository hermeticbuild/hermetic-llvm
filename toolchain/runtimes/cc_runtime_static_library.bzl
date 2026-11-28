load("@llvm//toolchain/runtimes:with_cfg_runtimes_common.bzl", "CXX_STDLIB_INHERITED_SANITIZERS", "configure_builder_for_runtimes")
load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_static_library,
)

# NOTE: runtime static libraries do not have >stage0 dependencies.
# Those are only needed for shared libraries.
cc_runtime_stage0_static_library, _cc_stage0_static_library_internal = configure_builder_for_runtimes(_builder.clone(), "stage0").build()

# Stage-0 archives for libc++ and libc++abi follow the C++ standard library
# sanitizer policy. They inherit the allowed caller settings, and the final
# link supplies the sanitizer runtime when one is enabled.
cc_runtime_stage0_cxxstdlib_static_library, _cc_stage0_cxxstdlib_static_library_internal = configure_builder_for_runtimes(
    _builder.clone(),
    "stage0",
    inherit_sanitizers = CXX_STDLIB_INHERITED_SANITIZERS,
).build()
