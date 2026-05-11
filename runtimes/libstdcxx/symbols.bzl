load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

def _libstdcxx_symbols_version_script_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    source_placeholder = "__libstdcxx_symbols_source__.ver"
    output_placeholder = "__libstdcxx_symbols_output__.ver"
    variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        source_file = source_placeholder,
        output_file = output_placeholder,
        user_compile_flags = [
            "-x",
            "c",
            "-E",
            "-P",
            "-include",
            ctx.file.config_h.path,
        ],
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
        variables = variables,
    )
    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
        variables = variables,
    )
    compiler = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
    )
    output = ctx.actions.declare_file(ctx.attr.name + ".ver")

    ctx.actions.run_shell(
        inputs = depset(
            direct = [ctx.file.base_version_script, ctx.file.config_h] + ctx.files.port_version_scripts,
            transitive = [cc_toolchain.all_files],
        ),
        outputs = [output],
        tools = cc_toolchain.all_files,
        arguments = [
            compiler,
            ctx.file.base_version_script.path,
            ctx.file.config_h.path,
            output.path,
            source_placeholder,
            output_placeholder,
        ] + [port.path for port in ctx.files.port_version_scripts] + ["--"] + command_line,
        env = env,
        command = """set -eu
compiler="$1"
base="$2"
config_h="$3"
output="$4"
source_placeholder="$5"
output_placeholder="$6"
shift 6
ports=()
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--" ]; then
        shift
        break
    fi
    ports+=("$1")
    shift
done

tmp="${TMPDIR:-/tmp}/libstdcxx-symbols-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT
combined="$tmp/libstdc++-symbols.ver.tmp"
filtered="$tmp/libstdc++-symbols.ver.filtered"
preprocessed="$tmp/libstdc++-symbols.ver.preprocessed"
cp "$base" "$combined"
chmod +w "$combined"

for port in "${ports[@]}"; do
    if grep '^# Appended to version file\\.' "$port" >/dev/null 2>&1; then
        cat "$port" >> "$combined"
    else
        sed -n '1,/DO NOT DELETE/p' "$combined" > "$tmp/top"
        sed -n '/DO NOT DELETE/,$p' "$combined" > "$tmp/bottom"
        cat "$tmp/top" "$port" "$tmp/bottom" > "$combined"
    fi
done

grep -Ev '^[[:space:]]*#(#| |$)' "$combined" > "$filtered"

cmd=("$compiler")
for arg in "$@"; do
    case "$arg" in
        "$source_placeholder")
            cmd+=("$filtered")
            ;;
        "$output_placeholder")
            cmd+=("$preprocessed")
            ;;
        *)
            cmd+=("$arg")
            ;;
    esac
done
"${cmd[@]}"
cp "$preprocessed" "$output"
""",
        execution_requirements = {"supports-path-mapping": "1"},
        mnemonic = "LibstdcxxSymbolsVersionScript",
        toolchain = CC_TOOLCHAIN_TYPE,
    )

    return [DefaultInfo(files = depset([output]))]

libstdcxx_symbols_version_script = rule(
    implementation = _libstdcxx_symbols_version_script_impl,
    attrs = {
        "base_version_script": attr.label(allow_single_file = True, mandatory = True),
        "config_h": attr.label(allow_single_file = True, mandatory = True),
        "port_version_scripts": attr.label_list(allow_files = True),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
