load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

ubsan_cc_binary, _ubsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:ubsan"),
    True,
).set(
    Label("@llvm//config:host_ubsan"),
    True,
).build()

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

asan_cc_binary, _asan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:asan"),
    True,
).set(
    Label("@llvm//config:host_asan"),
    True,
).build()

lsan_cc_binary, _lsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:lsan"),
    True,
).set(
    Label("@llvm//config:host_lsan"),
    True,
).build()

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

opt_binary, _opt_binary_internal = with_cfg(cc_binary).set(
    "compilation_mode",
    "opt",
).build()
