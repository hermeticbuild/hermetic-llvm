"""Checks that toolchain args share one configuration across runtime stages."""

_STAGES = {
    "complete": ("complete", "dynamic"),
    "stage0": ("stage0", "static"),
    "stage1": ("stage1", "static"),
    "stage1_hosted": ("stage1_hosted", "static"),
}

def _stages_impl(_settings, _attr):
    return {
        key: {
            "//runtimes:linkmode": linkmode,
            "//toolchain:runtime_stage": stage,
        }
        for key, (stage, linkmode) in _STAGES.items()
    }

_stages = transition(
    implementation = _stages_impl,
    inputs = [],
    outputs = ["//runtimes:linkmode", "//toolchain:runtime_stage"],
)

_BinDirInfo = provider("Output directory of a configured target.", fields = ["path"])

def _bin_dir_aspect_impl(_target, ctx):
    return [_BinDirInfo(path = ctx.bin_dir.path)]

_bin_dir_aspect = aspect(implementation = _bin_dir_aspect_impl)

def _bin_dirs(split_targets):
    bin_dirs = {}
    for targets in split_targets.values():
        for target in targets:
            bin_dirs.setdefault(str(target.label), {})[target[_BinDirInfo].path] = True
    return bin_dirs

def _stage_independent_test_impl(ctx):
    errors = [
        "{} is analysed in {} configurations".format(label, len(paths))
        for label, paths in _bin_dirs(ctx.split_attr.shared).items()
        if len(paths) != 1
    ] + [
        "{} is analysed in one configuration".format(label)
        for label, paths in _bin_dirs(ctx.split_attr.per_stage).items()
        if len(paths) != len(_STAGES)
    ]
    script = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = script,
        content = "#!/bin/sh\n" + "".join(["echo '{}' >&2\n".format(e) for e in errors]) + ("exit 1\n" if errors else "exit 0\n"),
        is_executable = True,
    )
    return [DefaultInfo(executable = script)]

stage_independent_test = rule(
    implementation = _stage_independent_test_impl,
    doc = "Passes when `shared` targets have one configuration for every runtime stage.",
    attrs = {
        "per_stage": attr.label_list(
            cfg = _stages,
            aspects = [_bin_dir_aspect],
            doc = "Targets that must have one configuration per runtime stage.",
        ),
        "shared": attr.label_list(
            cfg = _stages,
            aspects = [_bin_dir_aspect],
            doc = "Targets that must have one configuration for every runtime stage.",
        ),
    },
    test = True,
)
