load("//constraints/libc:libc_versions.bzl", "glibc_supported")

def _generate_glibc_stubs(actions, generator, abilist, target, directory):
    # type: (actions, File, File, str, str) -> tuple[File, dict[str, File]]
    version_script = actions.declare_file(directory + "/all.map")

    assembly_outputs = {
        "c": actions.declare_file(directory + "/c.s"),
        "dl": actions.declare_file(directory + "/dl.s"),
        "ld": actions.declare_file(directory + "/ld.s"),
        "m": actions.declare_file(directory + "/m.s"),
        "pthread": actions.declare_file(directory + "/pthread.s"),
        "resolv": actions.declare_file(directory + "/resolv.s"),
        "rt": actions.declare_file(directory + "/rt.s"),
        "util": actions.declare_file(directory + "/util.s"),
    }
    outputs = list(assembly_outputs.values()) + [version_script]

    args = actions.args()
    args.add("-target")
    args.add(target)
    args.add("-o")
    args.add(version_script.dirname)
    args.add(abilist)

    actions.run(
        executable = generator,
        inputs = [abilist],
        arguments = [args],
        outputs = outputs,
    )

    return version_script, assembly_outputs

def _glibc_stubs_impl(ctx):
    # type: (...) -> list[DefaultInfo | OutputGroupInfo]
    target = ctx.attr.target
    arch = target.split("-")[0]
    _, major, minor = target.rsplit(".", 2)
    if not glibc_supported(arch, major + "." + minor):
        fail("RISC-V requires glibc >= 2.27; requested {}".format(target))
    generator = ctx.executable._generator
    abilist = ctx.files.abilist[0]
    version_script, assembly_outputs = _generate_glibc_stubs(ctx.actions, generator, abilist, target, "build")

    prefix, major, minor = target.rsplit(".", 2)
    if int(major) > 2 or (int(major) == 2 and int(minor) >= 34):
        _, compatibility_outputs = _generate_glibc_stubs(ctx.actions, generator, abilist, prefix + ".2.33", "build/compat")
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
