load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

_TREE_ROOT_TOKEN = "__LLVM_LINKER_TREE__"

def _normalize_subpath(path):
    if path.startswith("/"):
        fail("tree input destination must be a relative path, got: %s" % path)
    parts = [part for part in path.split("/") if part]
    if not parts:
        fail("tree input destination cannot be empty")
    for part in parts:
        if part == "." or part == "..":
            fail("tree input destination must not contain '.' or '..': %s" % path)
    return "/".join(parts)

def _rewrite_arg(arg, prefix_rewrites):
    value = arg

    for prefix in ["--sysroot=", "-L", "-B"]:
        if value.startswith(prefix) and len(value) > len(prefix):
            rewritten = _rewrite_path(value[len(prefix):], prefix_rewrites)
            return prefix + rewritten

    return _rewrite_path(value, prefix_rewrites)

def _rewrite_path(path, prefix_rewrites):
    best = None
    for source in prefix_rewrites.keys():
        if path == source or path.startswith(source + "/"):
            if best == None or len(source) > len(best):
                best = source

    if best != None:
        suffix = path[len(best):]
        return prefix_rewrites[best] + suffix

    return path

def _collect_tree_inputs(ctx):
    entries = []
    prefix_rewrites = {}
    inputs = []

    for target, destination in ctx.attr.tree_inputs.items():
        destination = _normalize_subpath(destination)
        files = target.files.to_list()
        if not files:
            fail("tree input %s does not provide files" % target.label)
        for file in files:
            out_subpath = destination
            if len(files) > 1:
                out_subpath = destination + "/" + file.basename
            entries.append((file, out_subpath))
            inputs.append(file)
            rewrite_to = _TREE_ROOT_TOKEN + "/" + out_subpath
            prefix_rewrites[file.path] = rewrite_to
            prefix_rewrites[file.short_path] = rewrite_to

    return entries, prefix_rewrites, inputs

def _serialize_contract(arguments, environment):
    lines = ["# directive<TAB>payload"]

    for name in sorted(environment.keys()):
        lines.append("setenv\t%s\t%s" % (name, environment[name]))

    for argument in arguments:
        if argument:
            lines.append("arg\t%s" % argument)

    return "\n".join(lines) + "\n"

def _manifest_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = ctx.attr.is_linking_dynamic_library,
        runtime_library_search_directories = [],
        user_link_flags = ctx.attr.user_link_flags,
    )

    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ctx.attr.action_name,
        variables = variables,
    )
    link_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ctx.attr.action_name,
        variables = variables,
    )

    tree_entries, prefix_rewrites, tree_inputs = _collect_tree_inputs(ctx)
    rewritten_args = [_rewrite_arg(arg, prefix_rewrites) for arg in link_args]
    rewritten_env = {
        name: _rewrite_arg(value, prefix_rewrites)
        for name, value in link_env.items()
    }

    _ = tree_entries
    _ = tree_inputs
    ctx.actions.write(
        output = ctx.outputs.out,
        content = _serialize_contract(rewritten_args, rewritten_env),
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

linker_contract_manifest_from_cc_toolchain = rule(
    doc = "Expands cc_toolchain link args and emits a path-rewritten linker contract manifest.",
    implementation = _manifest_impl,
    attrs = {
        "out": attr.output(
            mandatory = True,
        ),
        "tree_inputs": attr.label_keyed_string_dict(
            allow_files = True,
            mandatory = True,
        ),
        "action_name": attr.string(
            default = ACTION_NAMES.cpp_link_executable,
        ),
        "is_linking_dynamic_library": attr.bool(
            default = False,
        ),
        "user_link_flags": attr.string_list(
            default = [],
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _tree_impl(ctx):
    tree_entries, _, tree_inputs = _collect_tree_inputs(ctx)
    out_tree = ctx.actions.declare_directory(ctx.attr.out_tree_name)

    copy_args = ctx.actions.args()
    copy_args.add(out_tree.path)
    for source, destination in tree_entries:
        copy_args.add(source.path)
        copy_args.add(destination)

    ctx.actions.run_shell(
        inputs = depset(tree_inputs),
        outputs = [out_tree],
        arguments = [copy_args],
        command = """set -euo pipefail
out_tree="$1"
shift
mkdir -p "$out_tree"
while [ "$#" -gt 0 ]; do
  src="$1"
  dest_rel="$2"
  shift 2
  dest="$out_tree/$dest_rel"
  mkdir -p "$(dirname "$dest")"
  if [ -d "$src" ]; then
    cp -RL "$src" "$dest"
  else
    cp -L "$src" "$dest"
  fi
done
""",
        mnemonic = "LinkerContractTree",
    )

    return [DefaultInfo(files = depset([out_tree]))]

linker_contract_tree = rule(
    doc = "Copies linker runtime inputs into a stable tree artifact layout.",
    implementation = _tree_impl,
    attrs = {
        "out_tree_name": attr.string(
            mandatory = True,
        ),
        "tree_inputs": attr.label_keyed_string_dict(
            allow_files = True,
            mandatory = True,
        ),
    },
)

def linker_contract_bundle(
        name,
        target_compatible_with,
        tree_inputs,
        action_name = ACTION_NAMES.cpp_link_executable,
        is_linking_dynamic_library = False,
        user_link_flags = []):
    linker_contract_manifest_from_cc_toolchain(
        name = name + "_manifest",
        out = name + ".txt",
        tree_inputs = tree_inputs,
        action_name = action_name,
        is_linking_dynamic_library = is_linking_dynamic_library,
        user_link_flags = user_link_flags,
        target_compatible_with = target_compatible_with,
    )
    linker_contract_tree(
        name = name + "_tree",
        out_tree_name = name + "_tree",
        tree_inputs = tree_inputs,
        target_compatible_with = target_compatible_with,
    )
