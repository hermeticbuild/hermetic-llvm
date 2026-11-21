"""Checks that coverage only instruments targets matching --instrumentation_filter."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")

_COMPILE_FLAGS = {
    "gcc": ["-fprofile-arcs", "-ftest-coverage"],
    "llvm": ["-fprofile-instr-generate", "-fcoverage-mapping"],
}

# Link actions need the coverage runtime even if the binary isn't instrumented
# itself, since its dependencies may be.
_LINK_FLAGS = {
    "gcc": ["--coverage"],
    "llvm": ["-fprofile-instr-generate"],
}

def _check_flags(action, flags, expected):
    # type: (Action, Sequence[str], bool) -> None
    argv = action.argv
    if argv == None:
        fail("%s action does not expose its arguments" % action.mnemonic)
    for flag in flags:
        if (flag in argv) != expected:
            fail("%s of %s: expected %s to be %s, got: %s" % (
                action.mnemonic,
                [f.short_path for f in action.outputs.to_list()],
                flag,
                "present" if expected else "absent",
                argv,
            ))

def _coverage_instrumentation_test_impl(ctx):
    # type: (ctx[object, struct[{"format": str, "instrumented": bool}, ...]]) -> list[AnalysisTestResultInfo]
    env = analysistest.begin(ctx)
    compiles = []
    links = []
    for action in analysistest.target_actions(env):
        if action.mnemonic == "CppCompile" and [f for f in action.outputs.to_list() if f.extension == "o"]:
            compiles.append(action)
        elif action.mnemonic == "CppLink":
            links.append(action)

    if not compiles:
        fail("Expected a source compilation")
    if not links:
        fail("Expected a link")
    for action in compiles:
        _check_flags(action, _COMPILE_FLAGS[ctx.attr.format], ctx.attr.instrumented)
    for action in links:
        _check_flags(action, _LINK_FLAGS[ctx.attr.format], True)
    return analysistest.end(env)

def _coverage_instrumentation_test(format, instrumentation_filter, instrumented):
    # type: (str, str, bool) -> rule
    return analysistest.make(
        _coverage_instrumentation_test_impl,
        attrs = {
            "format": attr.string(default = format),
            "instrumented": attr.bool(default = instrumented),
        },
        config_settings = {
            "//command_line_option:collect_code_coverage": True,
            "//command_line_option:experimental_use_llvm_covmap": format == "llvm",
            "//command_line_option:instrumentation_filter": instrumentation_filter,
        },
    )

# Matches the library, which makes the test instrumented as well since it may
# include instrumented headers of its direct dependency.
_INSTRUMENT_LIBRARY = ":coverage_lib$"

# Excludes every target.
_INSTRUMENT_NOTHING = "-.*"

llvm_coverage_instrumented_test = _coverage_instrumentation_test("llvm", _INSTRUMENT_LIBRARY, True)
llvm_coverage_not_instrumented_test = _coverage_instrumentation_test("llvm", _INSTRUMENT_NOTHING, False)
gcc_coverage_instrumented_test = _coverage_instrumentation_test("gcc", _INSTRUMENT_LIBRARY, True)
gcc_coverage_not_instrumented_test = _coverage_instrumentation_test("gcc", _INSTRUMENT_NOTHING, False)
