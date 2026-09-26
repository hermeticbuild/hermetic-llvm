"""glibc's static archives (libc.a, libm.a) and static startup files, from source.

glibc has no build description other than its makefiles, and those decide what
to compile through `sysdeps` directory ordering, `Implies` files, generated
makefile fragments and a configure run -- none of which exists in Bazel.  So
the build is *transcribed*: a reference `configure && make V=1` with this
toolchain's own Clang is reduced by `gen_manifest.py` to

  * a manifest (`<arch>/manifest.bzl`): for every object of libc.a and libm.a,
    its source file and its exact flags, with the directories of the reference
    build replaced by placeholders (flags are stored once, in FLAGS, and a
    flag set is a list of indexes into it), and
  * the files of the reference *build* tree those compiles read
    (`<arch>/gen/`): config.h, libc-modules.h, abi-versions.h, the
    gen-as-const offset headers, the syscall stubs make pipes into the
    assembler, ...  Everything else is the pristine release tarball.

This rule replays the manifest, one action per object, with the stage0
toolchain (a libc cannot be compiled by a toolchain that links it).
"""

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//toolchain/runtimes:cc_stage0_object.bzl", "bootstrap_transition")

# Archives glibc still installs but has emptied into libc.a (2.34 and later).
# `-lpthread -ldl -lrt` are in every other link line, so they have to exist.
_EMPTY_ARCHIVES = ["libpthread.a", "libdl.a", "librt.a", "libutil.a", "libanl.a"]

def _subst(s, src, gen, sub):
    return s.replace("{src}", src).replace("{gen}", gen).replace("{sub}", sub)

def _glibc_static_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    cc = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
    )
    ar = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_static_library,
    )

    # What the stage0 toolchain says about the target: the triple, the null
    # sysroot, where the kernel's and glibc's installed headers are (glibc's
    # own <limits.h> ends in an #include_next).  glibc's flags follow and win.
    toolchain_flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
        variables = cc_common.create_compile_variables(
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
        ),
    )

    # The kernel's headers and glibc's *installed* ones, as -isystem so they
    # come after every -I of the manifest: glibc's internal headers wrap the
    # installed ones with #include_next.
    header_inputs = []
    system_includes = []
    for dep in ctx.attr.deps:
        cc_ctx = dep[CcInfo].compilation_context
        header_inputs.append(cc_ctx.headers)
        for d in cc_ctx.system_includes.to_list() + cc_ctx.includes.to_list():
            system_includes.extend(["-isystem", d])

    src = ctx.file.src_marker.dirname
    gen = ctx.file.gen_marker.dirname
    inputs = depset(
        ctx.files.srcs + ctx.files.gen,
        transitive = [cc_toolchain.all_files] + header_inputs,
    )

    includes = ctx.attr.includes
    flag_sets = []
    for encoded in ctx.attr.flag_sets:
        flags = []
        for index in json.decode(encoded):
            f = ctx.attr.flags[index]
            if f == "@INCLUDES":
                flags.extend(includes)
            else:
                flags.append(f)
        flag_sets.append(flags)

    objects = {}
    for row in ctx.attr.objects:
        obj, source, sub, idx = row.split("|")
        out = ctx.actions.declare_file("{}/{}".format(ctx.label.name, obj))
        args = ctx.actions.args()
        args.add_all(toolchain_flags)

        # The generated tree first.  In the reference build it comes second,
        # after <src>/include -- but this toolchain's glibc repository carries
        # an *empty* include/config.h (patched in for the crt objects, which
        # need none), and that one must not shadow the real one.  No file name
        # exists in both the pristine include/ and the generated tree, so for
        # everything else the order is immaterial.
        args.add("-I" + gen)
        args.add_all([_subst(f, src, gen, sub) for f in flag_sets[int(idx)]])
        args.add_all(system_includes)

        # The reference build's warnings are glibc's business, not ours.
        args.add("-w")
        args.add("-c", _subst(source, src, gen, sub))
        args.add("-o", out)
        ctx.actions.run(
            executable = cc,
            arguments = [args],
            inputs = inputs,
            outputs = [out],
            mnemonic = "GlibcStaticCompile",
            progress_message = "Compiling glibc %s" % obj,
            toolchain = CC_TOOLCHAIN_TYPE,
        )
        objects[obj] = out

    outputs = []
    archives = json.decode(ctx.attr.archives)
    for name in _EMPTY_ARCHIVES:
        archives[name] = []
    for name, members in archives.items():
        out = ctx.actions.declare_file("{}/lib/{}".format(ctx.label.name, name))
        files = [objects[m] for m in members]
        args = ctx.actions.args()
        args.add("rcsD", out)
        args.add_all(files)
        args.use_param_file("@%s", use_always = True)
        args.set_param_file_format("multiline")
        ctx.actions.run(
            executable = ar,
            arguments = [args],
            inputs = depset(files, transitive = [cc_toolchain.all_files]),
            outputs = [out],
            mnemonic = "GlibcStaticArchive",
            toolchain = CC_TOOLCHAIN_TYPE,
        )
        outputs.append(out)

    crt_outputs = []
    for name, members in json.decode(ctx.attr.crt).items():
        out = ctx.actions.declare_file("{}/crt/{}".format(ctx.label.name, name))
        files = [objects[m] for m in members]
        args = ctx.actions.args()
        args.add("-target")
        args.add_all(ctx.attr.target_triple)
        args.add_all(["-fuse-ld=lld", "-nostdlib", "-nostartfiles", "-r"])
        args.add("-o", out)
        args.add_all(files)
        ctx.actions.run(
            executable = cc,
            arguments = [args],
            inputs = depset(files, transitive = [cc_toolchain.all_files]),
            outputs = [out],
            mnemonic = "GlibcStaticCrt",
            toolchain = CC_TOOLCHAIN_TYPE,
        )
        crt_outputs.append(out)

    return [
        DefaultInfo(files = depset(outputs + crt_outputs)),
        OutputGroupInfo(
            archives = depset(outputs),
            # One group per startup file ("crt1", "rcrt1", "crti", "crtn"): the
            # toolchain swaps them in one by one.
            **{f.basename[:-len(".o")]: depset([f]) for f in crt_outputs}
        ),
    ]

glibc_static = rule(
    implementation = _glibc_static_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "src_marker": attr.label(allow_single_file = True, mandatory = True, doc = "A file at the root of the glibc source tree."),
        "gen": attr.label_list(allow_files = True, mandatory = True),
        "gen_marker": attr.label(allow_single_file = True, mandatory = True, doc = "A file at the root of the generated tree."),
        "deps": attr.label_list(providers = [CcInfo], doc = "Kernel headers and glibc's installed headers."),
        "includes": attr.string_list(),
        "flags": attr.string_list(doc = "Every distinct flag, once."),
        "flag_sets": attr.string_list(doc = "One per flag set: a JSON list of indexes into `flags`."),
        "objects": attr.string_list(doc = "object|source|sub-directory|flag set"),
        "archives": attr.string(doc = "JSON: archive name -> objects"),
        "crt": attr.string(doc = "JSON: startup file name -> objects"),
        "target_triple": attr.string_list(mandatory = True),
    },
    cfg = bootstrap_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def glibc_static_for_arch(name, includes, flags, flag_sets, objects, archives, crt, **kwargs):
    """Instantiates glibc_static from the symbols of one <arch>/manifest.bzl."""
    glibc_static(
        name = name,
        includes = includes,
        flags = flags,
        flag_sets = [json.encode(f) for f in flag_sets],
        objects = ["|".join([o, s, sub, str(i)]) for (o, s, sub, i) in objects],
        archives = json.encode(archives),
        crt = json.encode(crt),
        **kwargs
    )
