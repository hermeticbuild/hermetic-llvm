def _generate_glibc_stubs(ctx, target, directory):
    version_script = ctx.actions.declare_file(directory + "/all.map")

    assembly_outputs = {
        "c": ctx.actions.declare_file(directory + "/c.s"),
        "dl": ctx.actions.declare_file(directory + "/dl.s"),
        "ld": ctx.actions.declare_file(directory + "/ld.s"),
        "m": ctx.actions.declare_file(directory + "/m.s"),
        "pthread": ctx.actions.declare_file(directory + "/pthread.s"),
        "resolv": ctx.actions.declare_file(directory + "/resolv.s"),
        "rt": ctx.actions.declare_file(directory + "/rt.s"),
        "util": ctx.actions.declare_file(directory + "/util.s"),
    }
    outputs = list(assembly_outputs.values()) + [version_script]

    args = ctx.actions.args()
    args.add("-target")
    args.add(target)
    args.add("-o")
    args.add(version_script.dirname)
    args.add(ctx.files.abilist[0])

    ctx.actions.run(
        executable = ctx.executable._generator,
        inputs = [ctx.files.abilist[0]],
        arguments = [args],
        outputs = outputs,
    )

    return version_script, assembly_outputs

def _glibc_stubs_impl(ctx):
    target = ctx.attr.target
    version_script, assembly_outputs = _generate_glibc_stubs(ctx, target, "build")

    prefix, major, minor = target.rsplit(".", 2)
    if int(major) > 2 or (int(major) == 2 and int(minor) >= 34):
        _, compatibility_outputs = _generate_glibc_stubs(ctx, prefix + ".2.33", "build/compat")
        for library in ["dl", "pthread", "rt", "util"]:
            assembly_outputs[library] = compatibility_outputs[library]

    outputs = list(assembly_outputs.values()) + [version_script]

    output_groups = {
        lib + "_s": depset([output])
        for (lib, output) in assembly_outputs.items()
    }
    output_groups["all_map"] = depset([version_script])

    return [
        DefaultInfo(files = depset(outputs)),
        OutputGroupInfo(**output_groups),
    ]

glibc_stubs_assembly_files = rule(
    implementation = _glibc_stubs_impl,
    attrs = {
        "target": attr.string(
            mandatory = True,
        ),
        "_generator": attr.label(
            default = "//runtimes/glibc:glibc-stubs-generator",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
        "abilist": attr.label(
            allow_single_file = True,
        ),
    },
    doc = "Generates glibc stub files for a given target.",
)
