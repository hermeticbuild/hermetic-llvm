"""Checks native FDO profile arguments and inputs on ThinLTO actions."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")

def _fdo_optimize_test_impl(ctx):
    env = analysistest.begin(ctx)
    compiles = []
    backends = []
    for action in analysistest.target_actions(env):
        if action.mnemonic == "CppCompile":
            compiles.append(action)
        elif action.mnemonic == "CcLtoBackendCompile":
            backends.append(action)

    # Fail during analysis so the Windows build-only checks enforce this too.
    if not compiles:
        fail("Expected a source compilation")
    if not backends:
        fail("Expected a ThinLTO backend compilation")
    for action in compiles + backends:
        profile_args = [arg for arg in action.argv if arg.startswith("-fprofile-use=")]
        expects_profile = action.mnemonic == "CppCompile" or ctx.attr.context_sensitive
        expected_count = 1 if expects_profile else 0
        if len(profile_args) != expected_count:
            fail("%s: expected %d profile arguments, got %s" % (action.mnemonic, expected_count, profile_args))
        if profile_args:
            profile_path = profile_args[0].removeprefix("-fprofile-use=")
            if profile_path not in [f.path for f in action.inputs.to_list()]:
                fail("Profile must be an action input: %s" % profile_path)
            if ctx.attr.context_sensitive and not profile_path.endswith("/MergedCS.profdata"):
                fail("Expected the merged ordinary and CS profile, got %s" % profile_path)
    return analysistest.end(env)

_FDO_SETTINGS = {
    "//command_line_option:compilation_mode": "opt",
    "//command_line_option:fdo_profile": str(Label("//:fdo_optimize_profile")),
}

fdo_optimize_test = analysistest.make(
    _fdo_optimize_test_impl,
    attrs = {"context_sensitive": attr.bool(default = False)},
    config_settings = _FDO_SETTINGS,
)

cs_fdo_optimize_test = analysistest.make(
    _fdo_optimize_test_impl,
    attrs = {"context_sensitive": attr.bool(default = True)},
    config_settings = dict(_FDO_SETTINGS, **{
        "//command_line_option:cs_fdo_profile": str(Label("//:cs_fdo_optimize_profile")),
    }),
)
