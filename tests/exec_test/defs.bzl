"""Checks the values forwarded by the execution-test wrapper."""

load("//:defs.bzl", "exec_test")

def _inner_impl(ctx):
    # type: (...) -> list[DefaultInfo]
    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(executable, "#!/usr/bin/env bash\nexit 0\n", is_executable = True)
    return [DefaultInfo(executable = executable)]

_inner = rule(implementation = _inner_impl, executable = True)

def exec_test_regression_tests():
    # type: () -> None
    observed = []  # type: list[tuple[list[str], list[str]]]

    def capture(*, name, data, tags):
        # type: (str, list[str], list[str]) -> None
        observed.append((list(data), list(tags)))
        data.append(name)
        tags.append("callback_mutated")
        _inner(name = name)

    # ty: ignore[non-static-type]
    exec_test(capture, name = "first")

    # ty: ignore[non-static-type]
    exec_test(capture, name = "second")
    supplied_data = []  # type: list[str]
    supplied_tags = ["manual", "custom"]

    # ty: ignore[non-static-type]
    exec_test(capture, name = "explicit", inner_data = supplied_data, tags = supplied_tags)

    if observed != [([], ["manual"]), ([], ["manual"]), ([], ["manual", "custom"])]:
        fail("unexpected callback inputs: %r" % (observed,))
    if supplied_data != ["explicit_"]:
        fail("explicit data lost its identity: %r" % supplied_data)
    if supplied_tags != ["manual", "custom"]:
        fail("callback mutated caller tags: %r" % supplied_tags)
