load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@with_cfg.bzl", "with_cfg")

# Wrap a with_cfg sanitizer cc_binary so it pulls in its macOS runtime
# automatically. On macOS the sanitizer runtime is a dylib and must be a
# dynamic_dep so it lands in runfiles with an @loader_path rpath and loads at
# run time; Linux links the static runtime, so nothing is added there. Callers
# never repeat the dynamic_dep per target.
def _with_macos_sanitizer_runtime(inner_binary, macos_runtime):
    def _macro(name, dynamic_deps = None, **kwargs):
        inner_binary(
            name = name,
            dynamic_deps = (dynamic_deps or []) + select({
                "@platforms//os:macos": [macos_runtime],
                "//conditions:default": [],
            }),
            **kwargs
        )

    return _macro

# buildifier: disable=unused-variable
_ubsan_cc_binary, _ubsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:ubsan"),
    True,
).set(
    Label("@llvm//config:host_ubsan"),
    True,
).build()

ubsan_cc_binary = _with_macos_sanitizer_runtime(
    _ubsan_cc_binary,
    "@llvm//runtimes/compiler-rt:clang_rt.ubsan_standalone.shared",
)

cfi_cc_binary, _cfi_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:cfi"),
    True,
).set(
    Label("@llvm//config:host_cfi"),
    True,
).build()

msan_cc_binary, _msan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:msan"),
    True,
).set(
    Label("@llvm//config:host_msan"),
    True,
).build()

dfsan_cc_binary, _dfsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:dfsan"),
    True,
).set(
    Label("@llvm//config:host_dfsan"),
    True,
).build()

fission_cc_binary, _fission_cc_binary_internal = with_cfg(cc_binary).set(
    "compilation_mode",
    "dbg",
).set(
    "fission",
    ["dbg"],
).build()

nsan_cc_binary, _nsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:nsan"),
    True,
).set(
    Label("@llvm//config:host_nsan"),
    True,
).build()

safestack_cc_binary, _safestack_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:safestack"),
    True,
).set(
    Label("@llvm//config:host_safestack"),
    True,
).build()

rtsan_cc_binary, _rtsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:rtsan"),
    True,
).set(
    Label("@llvm//config:host_rtsan"),
    True,
).build()

tysan_cc_binary, _tysan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:tysan"),
    True,
).set(
    Label("@llvm//config:host_tysan"),
    True,
).build()

tsan_cc_binary, _tsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:tsan"),
    True,
).set(
    Label("@llvm//config:host_tsan"),
    True,
).build()

# buildifier: disable=unused-variable
_asan_cc_binary, _asan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:asan"),
    True,
).set(
    Label("@llvm//config:host_asan"),
    True,
).build()

asan_cc_binary = _with_macos_sanitizer_runtime(
    _asan_cc_binary,
    "@llvm//runtimes/compiler-rt:clang_rt.asan.shared",
)

# buildifier: disable=unused-variable
_lsan_cc_binary, _lsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:lsan"),
    True,
).set(
    Label("@llvm//config:host_lsan"),
    True,
).build()

lsan_cc_binary = _with_macos_sanitizer_runtime(
    _lsan_cc_binary,
    "@llvm//runtimes/compiler-rt:clang_rt.lsan.shared",
)

xray_cc_binary, _xray_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:xray"),
    True,
).set(
    Label("@llvm//config:host_xray"),
    True,
).build()

fuzzer_cc_binary, _fuzzer_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:fuzzer"),
    True,
).set(
    Label("@llvm//config:ubsan"),
    True,
).set(
    Label("@llvm//config:host_fuzzer"),
    True,
).set(
    Label("@llvm//config:host_ubsan"),
    True,
).build()

fuzzer_asan_cc_binary, _fuzzer_asan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:fuzzer"),
    True,
).set(
    Label("@llvm//config:host_fuzzer"),
    True,
).set(
    Label("@llvm//config:asan"),
    True,
).set(
    Label("@llvm//config:host_asan"),
    True,
).build()

profile_cc_binary, _profile_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:profile"),
    True,
).set(
    Label("@llvm//config:host_profile"),
    True,
).set(
    Label("@llvm//config:safestack"),
    select({
        "@platforms//os:linux": True,
        "//conditions:default": False,
    }),
).set(
    Label("@llvm//config:host_safestack"),
    select({
        "@platforms//os:linux": True,
        "//conditions:default": False,
    }),
).build()

opt_binary, _opt_binary_internal = with_cfg(cc_binary).set(
    "compilation_mode",
    "opt",
).build()

# Sanitizer cc_test variants. cc_test links dynamically, so on macOS the
# sanitizer runtime dylib is supplied by the toolchain (dynamic_runtime_lib +
# the runtime_library_search_directories feature) -- no dynamic_deps needed
# here, unlike the cc_binary macros. These only apply the sanitizer settings.
ubsan_cc_test, _ubsan_cc_test_internal = with_cfg(cc_test).set(
    Label("@llvm//config:ubsan"),
    True,
).set(
    Label("@llvm//config:host_ubsan"),
    True,
).build()

asan_cc_test, _asan_cc_test_internal = with_cfg(cc_test).set(
    Label("@llvm//config:asan"),
    True,
).set(
    Label("@llvm//config:host_asan"),
    True,
).build()

lsan_cc_test, _lsan_cc_test_internal = with_cfg(cc_test).set(
    Label("@llvm//config:lsan"),
    True,
).set(
    Label("@llvm//config:host_lsan"),
    True,
).build()
