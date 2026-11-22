"""Checks sanitizer link policy through consuming C++ actions."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

_GNU_SETTINGS = {
    "//command_line_option:platforms": str(Label("@llvm//platforms:linux_x86_64_gnu.2.34")),
}

def _link_test_impl(ctx):
    env = analysistest.begin(ctx)
    links = [action for action in analysistest.target_actions(env) if action.mnemonic == "CppLink"]
    asserts.equals(env, 1, len(links))
    if links:
        asserts.equals(env, ctx.attr.non_pie, "-no-pie" in links[0].argv)
        asserts.equals(env, ctx.attr.fully_static, "-static" in links[0].argv)
    return analysistest.end(env)

_LINK_ATTRS = {
    "fully_static": attr.bool(),
    "non_pie": attr.bool(),
}

ordinary_link_test = analysistest.make(_link_test_impl, attrs = _LINK_ATTRS, config_settings = _GNU_SETTINGS)

tsan_link_test = analysistest.make(
    _link_test_impl,
    attrs = _LINK_ATTRS,
    config_settings = dict(_GNU_SETTINGS, **{str(Label("@llvm//config:tsan")): True}),
)

tsan_force_pic_link_test = analysistest.make(
    _link_test_impl,
    attrs = _LINK_ATTRS,
    config_settings = dict(_GNU_SETTINGS, **{
        "//command_line_option:force_pic": True,
        str(Label("@llvm//config:tsan")): True,
    }),
)

host_tsan_link_test = analysistest.make(
    _link_test_impl,
    attrs = _LINK_ATTRS,
    config_settings = dict(_GNU_SETTINGS, **{str(Label("@llvm//config:host_tsan")): True}),
)

def _static_rejected_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "sanitizer_requires_dynamic_libc")
    return analysistest.end(env)

asan_static_rejected_test = analysistest.make(
    _static_rejected_test_impl,
    config_settings = dict(_GNU_SETTINGS, **{str(Label("@llvm//config:asan")): True}),
    expect_failure = True,
)

msan_static_rejected_test = analysistest.make(
    _static_rejected_test_impl,
    config_settings = dict(_GNU_SETTINGS, **{str(Label("@llvm//config:msan")): True}),
    expect_failure = True,
)

tsan_static_rejected_test = analysistest.make(
    _static_rejected_test_impl,
    config_settings = dict(_GNU_SETTINGS, **{str(Label("@llvm//config:tsan")): True}),
    expect_failure = True,
)

def sanitizer_link_tests(name):
    """Exercise default linkage and target-local fully_static_link requests.

    Args:
        name: Name of the test suite and prefix for its targets.
    """
    cc_binary(
        name = name + "_probe",
        testonly = True,
        srcs = ["profile_main.cc"],
        tags = ["manual"],
    )
    cc_binary(
        name = name + "_static_probe",
        testonly = True,
        srcs = ["profile_main.cc"],
        features = ["fully_static_link"],
        tags = ["manual"],
    )
    tests = []
    for suffix, test_rule, static, non_pie in [
        ("ordinary", ordinary_link_test, False, True),
        ("ordinary_static", ordinary_link_test, True, True),
        ("tsan", tsan_link_test, False, False),
        ("tsan_force_pic", tsan_force_pic_link_test, False, False),
        ("host_tsan_only", host_tsan_link_test, False, True),
        ("asan_static_rejected", asan_static_rejected_test, True, None),
        ("msan_static_rejected", msan_static_rejected_test, True, None),
        ("tsan_static_rejected", tsan_static_rejected_test, True, None),
    ]:
        test_name = name + "_" + suffix + "_test"
        test_rule(
            name = test_name,
            target_compatible_with = select({
                "@platforms//os:linux": [],
                "//conditions:default": ["@platforms//:incompatible"],
            }),
            target_under_test = name + ("_static_probe" if static else "_probe"),
            **({"fully_static": static, "non_pie": non_pie} if non_pie != None else {})
        )
        tests.append(test_name)
    native.test_suite(name = name, tests = tests)
