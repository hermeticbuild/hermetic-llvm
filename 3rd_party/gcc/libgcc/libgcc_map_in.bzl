# Step one of generating the version script of libgcc_s.so.1: libgcc.map.in,
# the list of every symbol GCC's libgcc_s exports and the version node each
# was introduced in, for the selected GCC release and target.
#
# GCC keeps the symbol list in libgcc/libgcc-std.ver.in (generic) plus
# per-target fragments under libgcc/config/ (SHLIB_MAPFILES, chosen by
# config.host). They use a small preprocessor-like syntax: %ifdef / %else /
# %endif / %define guards on target macros such as __x86_64__, and %inherit /
# %exclude lines that only the awk understands. libgcc/Makefile.in turns them
# into libgcc.map.in with:
#
#   libgcc-std.ver: libgcc-std.ver.in
#       sed -e "s/__PFX__/$(LIBGCC_VER_GNU_PREFIX)/" \
#           -e "s/__FIXPTPFX__/$(LIBGCC_VER_FIXEDPOINT_GNU_PREFIX)/" < $< > $@
#
#   libgcc.map.in: $(SHLIB_MAPFILES)   # libgcc-std.ver + the target's config/*.ver
#       sed -e '/^[ \t]*#/d' -e 's/^%\(if\|else\|elif\|endif\|define\)/#\1/' \
#           $(SHLIB_MAPFILES) | $(gcc_compile) -E -xassembler-with-cpp - > $@
#
# That is: fill in the symbol prefix of the generic file, append the target
# fragments, strip # comments, turn the %-guards into real C preprocessor
# directives, and run the *target* compiler's preprocessor so the guards
# resolve for the platform being built.
#
# Implementation: the same steps as two Bazel actions. A shell step does the
# text munging (the two sed recipes fused into one pipeline), and a second
# action runs the preprocessor. The preprocessor command line is obtained
# from the C++ toolchain (compiler, -target, sysroot, include directories)
# rather than hardcoded, so it is the target's preprocessor by construction.

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

# The two recipes up to the preprocessor run. Arguments: output, the two
# prefixes, libgcc-std.ver.in, then the target mapfiles. The braces produce
# the concatenated SHLIB_MAPFILES (prefixes substituted in the std file only);
# the sed after the pipe deletes comment lines and rewrites the %-markers at
# line start, so %ifdef/%ifndef become #ifdef/#ifndef too, while %inherit and
# %exclude stay as they are: those are mkmap-symver.awk's, not cpp's.
_CONCATENATE_COMMAND = """set -eu
out="$1"
gnu_prefix="$2"
fixedpoint_gnu_prefix="$3"
std_ver_in="$4"
shift 4

{
    sed -e "s/__PFX__/${gnu_prefix}/g" \\
        -e "s/__FIXPTPFX__/${fixedpoint_gnu_prefix}/g" "${std_ver_in}"
    if [ "$#" -gt 0 ]; then
        cat "$@"
    fi
} | sed -e '/^[ \t]*#/d' \\
        -e 's/^%if/#if/' \\
        -e 's/^%else/#else/' \\
        -e 's/^%elif/#elif/' \\
        -e 's/^%endif/#endif/' \\
        -e 's/^%define/#define/' \\
    > "$out"
"""

def _libgcc_map_in_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )

    # Stand-ins for the source and output files while asking the toolchain
    # for its command line: cc_common takes paths as strings, and the real
    # Files are substituted into the Args below so Bazel tracks them.
    source_placeholder = "__libgcc_map_in_source__.ver"
    output_placeholder = "__libgcc_map_in_output__.ver"

    # Step 1 output: the concatenated, comment-free, cpp-ready version text.
    concatenated = ctx.actions.declare_file(ctx.label.name + ".ver")

    # Step 2 output: the same after the target preprocessor, libgcc.map.in.
    output = ctx.actions.declare_file(ctx.label.name)

    # Step 1: the sed recipes.
    ctx.actions.run_shell(
        inputs = [ctx.file.std_ver_in] + ctx.files.mapfiles,
        outputs = [concatenated],
        arguments = [
            concatenated.path,
            ctx.attr.gnu_prefix,
            ctx.attr.fixedpoint_gnu_prefix,
            ctx.file.std_ver_in.path,
        ] + [mapfile.path for mapfile in ctx.files.mapfiles],
        command = _CONCATENATE_COMMAND,
        mnemonic = "LibgccMapInConcatenate",
    )

    # Step 2: `$(gcc_compile) -E -xassembler-with-cpp`, hermetically. Rather
    # than hardcoding a compiler path and target flags, ask the C++ toolchain
    # for the command line it would use for a preprocess-assemble action
    # (compiler, -target, sysroot, include directories, environment) and
    # adjust it: this is the same pattern as //toolchain/runtimes:cc_stage0_object.bzl.
    preprocess_action = ACTION_NAMES.preprocess_assemble
    variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        source_file = source_placeholder,
        output_file = output_placeholder,
        # -xassembler-with-cpp as in libgcc/Makefile.in; -P only drops the
        # line markers that mkmap-symver.awk would skip as comments anyway.
        user_compile_flags = [
            "-x",
            "assembler-with-cpp",
            "-E",
            "-P",
        ],
    )
    raw_command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = preprocess_action,
        variables = variables,
    )
    command_line = [
        arg
        for arg in raw_command_line
        # The cc action template is compile-shaped. This action only
        # preprocesses the version script, so keep the cc_common-derived
        # target and include flags but drop the compile-only marker.
        if arg != "-c"
    ]
    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = preprocess_action,
        variables = variables,
    )
    compiler = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = preprocess_action,
    )

    # Rebuild the command line with the real files in place of the
    # placeholders.
    preprocessor_args = ctx.actions.args()
    for arg in command_line:
        if arg == source_placeholder:
            preprocessor_args.add(concatenated)
        elif arg == output_placeholder:
            preprocessor_args.add(output)
        else:
            preprocessor_args.add(arg)

    ctx.actions.run(
        executable = compiler,
        # all_files brings the compiler binary and its resource directory
        # into the sandbox.
        inputs = depset(
            direct = [concatenated],
            transitive = [cc_toolchain.all_files],
        ),
        outputs = [output],
        arguments = [preprocessor_args],
        env = env,
        mnemonic = "LibgccMapInPreprocess",
        toolchain = CC_TOOLCHAIN_TYPE,
    )

    return [DefaultInfo(files = depset([output]))]

libgcc_map_in = rule(
    implementation = _libgcc_map_in_impl,
    doc = "Generates libgcc.map.in from libgcc-std.ver.in and the target's version fragments, as libgcc/Makefile.in does.",
    attrs = {
        # libgcc-std.ver.in: the generic symbol list, shared by every target.
        "std_ver_in": attr.label(allow_single_file = True, mandatory = True),
        # The rest of SHLIB_MAPFILES: the config/*.ver fragments the target's
        # config.host entry lists, in that order.
        "mapfiles": attr.label_list(allow_files = True),
        # LIBGCC_VER_GNU_PREFIX and LIBGCC_VER_FIXEDPOINT_GNU_PREFIX from
        # libgcc/Makefile.in; t-fixedpoint-gnu-prefix targets use __gnu_.
        "gnu_prefix": attr.string(default = "__"),
        "fixedpoint_gnu_prefix": attr.string(default = "__"),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
