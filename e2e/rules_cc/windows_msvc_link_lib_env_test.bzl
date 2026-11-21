"""Checks the LIB environment of MSVC link actions.

Tools such as rules_rust read LIB from the C++ link environment to find the
Windows SDK and CRT import libraries, so it must name the same hermetic
directories the link itself uses.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_PLATFORM = Label("@llvm//platforms:windows_x86_64_msvc")

def _has_suffix(entries, suffix):
    return any([entry.endswith("/" + suffix) for entry in entries])

def _windows_msvc_link_lib_env_test_impl(ctx):
    env = analysistest.begin(ctx)
    links = [
        action
        for action in analysistest.target_actions(env)
        if action.mnemonic == "CppLink"
    ]
    asserts.equals(env, 1, len(links), "expected one CppLink action")
    if len(links) != 1:
        return analysistest.end(env)
    link = links[0]

    lib = link.env.get("LIB")
    asserts.true(env, lib, "CppLink env does not set LIB: %s" % link.env)
    if not lib:
        return analysistest.end(env)
    asserts.false(env, "__hermetic_llvm_empty_lib__" in lib, "LIB is the empty placeholder: %s" % lib)

    entries = lib.split(";")
    input_paths = [file.path for file in link.inputs.to_list()]
    for entry in entries:
        asserts.true(
            env,
            any([path == entry or path.startswith(entry + "/") for path in input_paths]),
            "LIB entry %s is not an input of the link action" % entry,
        )

    for expected in ctx.attr.expected_directories:
        asserts.true(env, _has_suffix(entries, expected), "LIB does not contain %s: %s" % (expected, lib))
    for unexpected in ctx.attr.unexpected_directories:
        asserts.false(env, _has_suffix(entries, unexpected), "LIB unexpectedly contains %s: %s" % (unexpected, lib))

    return analysistest.end(env)

_ATTRS = {
    # Path suffixes of LIB entries.
    "expected_directories": attr.string_list(),
    "unexpected_directories": attr.string_list(),
}

windows_msvc_dynamic_crt_link_lib_env_test = analysistest.make(
    _windows_msvc_link_lib_env_test_impl,
    attrs = _ATTRS,
    config_settings = {
        "//command_line_option:features": ["-static_link_msvcrt", "dynamic_link_msvcrt"],
        "//command_line_option:platforms": [_PLATFORM],
    },
)

windows_msvc_static_crt_link_lib_env_test = analysistest.make(
    _windows_msvc_link_lib_env_test_impl,
    attrs = _ATTRS,
    config_settings = {
        "//command_line_option:features": ["-dynamic_link_msvcrt", "static_link_msvcrt"],
        "//command_line_option:platforms": [_PLATFORM],
    },
)
