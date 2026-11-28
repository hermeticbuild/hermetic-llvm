# Rules for the generated parts of libgcc's build. Compare with
# libgcc/Makefile.in: the per-function libgcc2.c compiles, gen-hide-list and
# the libgcc.map.in and libgcc.map recipes.

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _libgcc_wrappers_impl(ctx):
    outputs = []
    for path, content in ctx.attr.files.items():
        out = ctx.actions.declare_file(ctx.label.name + "/" + path)
        ctx.actions.write(out, content)
        outputs.append(out)
    return [DefaultInfo(files = depset(outputs))]

# libgcc/Makefile.in compiles libgcc2.c once per function with -DL<function>,
# and soft-fp wrappers the same way. A source file per object that defines the
# macro and includes the shared source gives each object its own name, so the
# objects of one compile mode can share a cc_library.
libgcc_wrappers = rule(
    implementation = _libgcc_wrappers_impl,
    attrs = {
        "files": attr.string_dict(
            doc = "Maps each generated path, relative to a directory named after the target, to its content.",
            mandatory = True,
        ),
    },
)

def _objects(deps):
    objects = []
    for dep in deps:
        for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                objects.extend(library.pic_objects or library.objects)
    return objects

def _object_stem(obj):
    name = obj.basename
    for suffix in [".pic.o", ".o"]:
        if name.endswith(suffix):
            return name[:-len(suffix)]
    return name

def _libgcc_hide_lists_impl(ctx):
    outputs = []
    for obj in _objects(ctx.attr.deps):
        out = ctx.actions.declare_file("{}/{}.vis".format(ctx.label.name, _object_stem(obj)))
        args = ctx.actions.args()
        args.add(ctx.executable._nm)
        args.add(obj)
        args.add(out)

        # gen-hide-list from libgcc/Makefile.in, with ASM_HIDDEN_OP=.hidden.
        ctx.actions.run_shell(
            inputs = [obj],
            outputs = [out],
            tools = [ctx.executable._nm],
            arguments = [args],
            command = """set -eu
"$1" -pg "$2" | awk 'NF == 3 && $2 !~ /^[UN]$/ && $3 !~ /.*_compat/ && $3 !~ /.*@.*/ { print "\\t.hidden", $3 }' > "$3"
""",
            mnemonic = "LibgccHideList",
        )
        outputs.append(out)
    return [DefaultInfo(files = depset(outputs))]

# Static-only assembly objects hide every global they define, from a list made
# from the shared (-DSHARED) compile of the same source.
libgcc_hide_lists = rule(
    implementation = _libgcc_hide_lists_impl,
    attrs = {
        "deps": attr.label_list(providers = [CcInfo], mandatory = True),
        "_nm": attr.label(
            default = "@llvm//tools:llvm-nm",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def _libgcc_version_script_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )

    # libgcc-std.ver and libgcc.map.in from libgcc/Makefile.in. The map files
    # are concatenated, comments are dropped and %if-style lines become
    # preprocessor directives, then the result is preprocessed as assembler.
    assembled = ctx.actions.declare_file(ctx.attr.name + ".map.S")
    args = ctx.actions.args()
    args.add(assembled)
    args.add(ctx.file.std_ver)
    args.add_all(ctx.files.map_files)
    ctx.actions.run_shell(
        inputs = [ctx.file.std_ver] + ctx.files.map_files,
        outputs = [assembled],
        arguments = [args],
        command = """set -eu
out="$1"
std="$2"
shift 2
{ sed -e 's/__PFX__/__/g' -e 's/__FIXPTPFX__/__/g' < "$std"; cat "$@"; } \
  | sed -e '/^[ 	]*#/d' -e 's/^%\\(if\\|else\\|elif\\|endif\\|define\\)/#\\1/' > "$out"
""",
        mnemonic = "LibgccMapAssemble",
    )

    source_placeholder = "__libgcc_map_source__.S"
    output_placeholder = "__libgcc_map_output__.in"
    preprocess_action = ACTION_NAMES.preprocess_assemble
    variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        source_file = source_placeholder,
        output_file = output_placeholder,
        user_compile_flags = ["-E", "-P"],
    )
    command_line = [
        arg
        for arg in cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = preprocess_action,
            variables = variables,
        )
        # The action template is compile-shaped; this only preprocesses.
        if arg != "-c"
    ]
    map_in = ctx.actions.declare_file(ctx.attr.name + ".map.in")
    preprocess_args = ctx.actions.args()
    for arg in command_line:
        if arg == source_placeholder:
            preprocess_args.add(assembled)
        elif arg == output_placeholder:
            preprocess_args.add(map_in)
        else:
            preprocess_args.add(arg)
    ctx.actions.run(
        executable = cc_common.get_tool_for_action(
            feature_configuration = feature_configuration,
            action_name = preprocess_action,
        ),
        inputs = depset(direct = [assembled], transitive = [cc_toolchain.all_files]),
        outputs = [map_in],
        arguments = [preprocess_args],
        env = cc_common.get_environment_variables(
            feature_configuration = feature_configuration,
            action_name = preprocess_action,
            variables = variables,
        ),
        mnemonic = "LibgccMapPreprocess",
        toolchain = CC_TOOLCHAIN_TYPE,
    )

    # libgcc.map: mkmap-symver.awk keeps the symbols the shared objects define.
    objects = _objects(ctx.attr.deps)
    output = ctx.actions.declare_file(ctx.attr.name + ".map")
    map_args = ctx.actions.args()
    map_args.add(ctx.executable._nm)
    map_args.add(ctx.file.mkmap)
    map_args.add(map_in)
    map_args.add(output)
    map_args.add_all(objects)
    ctx.actions.run_shell(
        inputs = [ctx.file.mkmap, map_in] + objects,
        outputs = [output],
        tools = [ctx.executable._nm],
        arguments = [map_args],
        command = """set -eu
nm="$1"
mkmap="$2"
map_in="$3"
out="$4"
shift 4
{ "$nm" -pg "$@"; echo %%; cat "$map_in"; } | awk -f "$mkmap" > "$out"
""",
        mnemonic = "LibgccMap",
    )
    return [DefaultInfo(files = depset([output]))]

libgcc_version_script = rule(
    implementation = _libgcc_version_script_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "The libgcc_s objects, in the shared compile mode.",
            providers = [CcInfo],
            mandatory = True,
        ),
        "map_files": attr.label_list(
            doc = "SHLIB_MAPFILES after libgcc-std.ver, in order.",
            allow_files = True,
        ),
        "mkmap": attr.label(allow_single_file = True, mandatory = True),
        "std_ver": attr.label(
            doc = "libgcc/libgcc-std.ver.in.",
            allow_single_file = True,
            mandatory = True,
        ),
        "_nm": attr.label(
            default = "@llvm//tools:llvm-nm",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
