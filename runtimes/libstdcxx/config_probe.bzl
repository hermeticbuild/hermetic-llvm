load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load(":config_checks.bzl", "COMPILE_CHECKS", "LINK_CHECKS", "POLICY_DEFINES")

_SANITIZER_SETTINGS = [
    "//config:asan",
    "//config:msan",
    "//config:dfsan",
    "//config:nsan",
    "//config:safestack",
    "//config:rtsan",
    "//config:tysan",
    "//config:tsan",
    "//config:ubsan",
    "//config:cfi",
    "//config:lsan",
    "//config:xray",
    "//config:fuzzer",
    "//config:profile",
    "//config:host_asan",
    "//config:host_msan",
    "//config:host_dfsan",
    "//config:host_nsan",
    "//config:host_safestack",
    "//config:host_rtsan",
    "//config:host_tysan",
    "//config:host_tsan",
    "//config:host_ubsan",
    "//config:host_cfi",
    "//config:host_lsan",
    "//config:host_xray",
    "//config:host_fuzzer",
    "//config:host_profile",
]

def _config_probe_transition_impl(_settings, _attr):
    settings = {
        "//toolchain:cxxstdlib_mode": "disabled",
        "//command_line_option:copt": [],
        "//command_line_option:cxxopt": [],
        "//command_line_option:conlyopt": [],
        "//command_line_option:linkopt": [],
        "//command_line_option:host_copt": [],
        "//command_line_option:host_cxxopt": [],
        "//command_line_option:host_conlyopt": [],
        "//command_line_option:host_linkopt": [],
    }
    for sanitizer in _SANITIZER_SETTINGS:
        settings[sanitizer] = False
    return settings

config_probe_transition = transition(
    implementation = _config_probe_transition_impl,
    inputs = [],
    outputs = [
        "//toolchain:cxxstdlib_mode",
        "//command_line_option:copt",
        "//command_line_option:cxxopt",
        "//command_line_option:conlyopt",
        "//command_line_option:linkopt",
        "//command_line_option:host_copt",
        "//command_line_option:host_cxxopt",
        "//command_line_option:host_conlyopt",
        "//command_line_option:host_linkopt",
    ] + _SANITIZER_SETTINGS,
)

def _compile_template(cc_toolchain, feature_configuration, action_name, source_file, output_file, user_compile_flags):
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = user_compile_flags,
        source_file = source_file,
        output_file = output_file,
    )
    return struct(
        command_line = cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = action_name,
            variables = compile_variables,
        ),
        env = cc_common.get_environment_variables(
            feature_configuration = feature_configuration,
            action_name = action_name,
            variables = compile_variables,
        ),
        tool = cc_common.get_tool_for_action(
            feature_configuration = feature_configuration,
            action_name = action_name,
        ),
    )

def _link_template(cc_toolchain, feature_configuration, output_file):
    link_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        output_file = output_file,
        is_using_linker = True,
        is_linking_dynamic_library = False,
    )
    return struct(
        command_line = cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.cpp_link_executable,
            variables = link_variables,
        ),
        env = cc_common.get_environment_variables(
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.cpp_link_executable,
            variables = link_variables,
        ),
        tool = cc_common.get_tool_for_action(
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.cpp_link_executable,
        ),
    )

def _declare_source(ctx, check):
    stem = ctx.attr.name + "_" + check.name.lower()
    extension = ".cc" if check.language == "c++" else ".c"
    source = ctx.actions.declare_file(stem + extension)
    ctx.actions.write(
        output = source,
        content = check.source,
    )
    return source

def _declare_compile_probe(ctx, cc_toolchain, check, template, source_placeholder, output_placeholder):
    source = _declare_source(ctx, check)
    stem = ctx.attr.name + "_" + check.name.lower()
    result = ctx.actions.declare_file(stem + ".result")
    log = ctx.actions.declare_file(stem + ".log")

    ctx.actions.run_shell(
        inputs = depset(
            direct = [source],
            transitive = [cc_toolchain.all_files],
        ),
        outputs = [result, log],
        tools = cc_toolchain.all_files,
        arguments = [
            template.tool,
            source.path,
            result.path,
            log.path,
            source_placeholder,
            output_placeholder,
        ] + check.flags + ["--"] + template.command_line,
        env = template.env,
        command = """set -eu
tool="$1"
source="$2"
result="$3"
log="$4"
source_placeholder="$5"
output_placeholder="$6"
shift 6
extra_flags=()
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--" ]; then
        shift
        break
    fi
    extra_flags+=("$1")
    shift
done

tmp="${TMPDIR:-/tmp}/libstdcxx-config-probe-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT
object="$tmp/probe.o"

cmd=("$tool")
for arg in "$@"; do
    case "$arg" in
        "$source_placeholder")
            cmd+=("${extra_flags[@]}")
            cmd+=("$source")
            ;;
        "$output_placeholder")
            cmd+=("$object")
            ;;
        *)
            cmd+=("$arg")
            ;;
    esac
done

if "${cmd[@]}" >"$log" 2>&1; then
    echo true > "$result"
else
    echo false > "$result"
fi
""",
        execution_requirements = {"supports-path-mapping": "1"},
        mnemonic = "LibstdcxxConfigCompileProbe",
        toolchain = CC_TOOLCHAIN_TYPE,
    )
    return struct(
        check = check,
        kind = "compile",
        result = result,
    )

def _declare_link_probe(ctx, cc_toolchain, check, compile_template, link_template, source_placeholder, object_placeholder, binary_placeholder):
    source = _declare_source(ctx, check)
    stem = ctx.attr.name + "_" + check.name.lower()
    result = ctx.actions.declare_file(stem + ".result")
    log = ctx.actions.declare_file(stem + ".log")

    ctx.actions.run_shell(
        inputs = depset(
            direct = [source],
            transitive = [cc_toolchain.all_files],
        ),
        outputs = [result, log],
        tools = cc_toolchain.all_files,
        arguments = [
            compile_template.tool,
            link_template.tool,
            source.path,
            result.path,
            log.path,
            source_placeholder,
            object_placeholder,
            binary_placeholder,
        ] + check.compile_flags + ["--"] + compile_template.command_line + ["--"] + check.link_flags + ["--"] + link_template.command_line,
        env = compile_template.env | link_template.env,
        command = """set -eu
compile_tool="$1"
link_tool="$2"
source="$3"
result="$4"
log="$5"
source_placeholder="$6"
object_placeholder="$7"
binary_placeholder="$8"
shift 8
compile_extra_flags=()
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--" ]; then
        shift
        break
    fi
    compile_extra_flags+=("$1")
    shift
done
compile_args=()
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--" ]; then
        shift
        break
    fi
    compile_args+=("$1")
    shift
done
link_extra_flags=()
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--" ]; then
        shift
        break
    fi
    link_extra_flags+=("$1")
    shift
done

tmp="${TMPDIR:-/tmp}/libstdcxx-config-link-probe-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT
object="$tmp/probe.o"
binary="$tmp/probe.exe"

compile_cmd=("$compile_tool")
for arg in "${compile_args[@]}"; do
    case "$arg" in
        "$source_placeholder")
            compile_cmd+=("${compile_extra_flags[@]}")
            compile_cmd+=("$source")
            ;;
        "$object_placeholder")
            compile_cmd+=("$object")
            ;;
        *)
            compile_cmd+=("$arg")
            ;;
    esac
done

link_cmd=("$link_tool")
for arg in "$@"; do
    case "$arg" in
        "$binary_placeholder")
            link_cmd+=("$binary")
            ;;
        *)
            link_cmd+=("$arg")
            ;;
    esac
done
link_cmd+=("$object")
link_cmd+=("${link_extra_flags[@]}")

if "${compile_cmd[@]}" >"$log" 2>&1 && "${link_cmd[@]}" >>"$log" 2>&1; then
    echo true > "$result"
else
    echo false > "$result"
fi
""",
        execution_requirements = {"supports-path-mapping": "1"},
        mnemonic = "LibstdcxxConfigLinkProbe",
        toolchain = CC_TOOLCHAIN_TYPE,
    )
    return struct(
        check = check,
        kind = "link",
        result = result,
    )

def _policy_result(policy):
    return struct(
        check = policy,
        kind = policy.kind,
        result = None,
    )

def _write_config_outputs(ctx, config_h, summary, results):
    arguments = [
        config_h.path,
        summary.path,
        ctx.attr.host_triple,
        ctx.attr.cpu_include_dir,
        ctx.attr.os_include_dir,
        ctx.attr.abi_baseline_pair,
        ctx.attr.abi_tweaks_dir,
        ctx.attr.atomicity_dir,
        ctx.attr.atomic_word_dir,
        ctx.attr.cpu_defines_dir,
        ctx.attr.error_constants_dir,
    ]
    inputs = []
    for result in results:
        result_path = ""
        if result.result:
            result_path = result.result.path
            inputs.append(result.result)
        arguments.extend([
            result.check.name,
            result.kind,
            getattr(result.check, "language", "policy"),
            getattr(result.check, "value", ""),
            result_path,
        ])

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = [config_h, summary],
        arguments = arguments,
        command = """set -eu
config_h="$1"
summary="$2"
host_triple="$3"
cpu_include_dir="$4"
os_include_dir="$5"
abi_baseline_pair="$6"
abi_tweaks_dir="$7"
atomicity_dir="$8"
atomic_word_dir="$9"
cpu_defines_dir="${10}"
error_constants_dir="${11}"
shift 11
tmp="${TMPDIR:-/tmp}/libstdcxx-config-output-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT
checks_json="$tmp/checks.json"
: > "$checks_json"

{
    echo "/* Generated by @llvm//runtimes/libstdcxx:config_h. */"
    echo "#ifndef LLVM_LIBSTDCXX_CONFIG_H"
    echo "#define LLVM_LIBSTDCXX_CONFIG_H 1"
    comma=""
    while [ "$#" -gt 0 ]; do
        name="$1"
        kind="$2"
        language="$3"
        value="$4"
        result_file="$5"
        shift 5
        if [ "$kind" = "define" ]; then
            echo "#define $name $value"
            printf '%s    "%s": {"kind": "%s", "value": "%s"}' "$comma" "$name" "$kind" "$value" >> "$checks_json"
        elif [ "$kind" = "undef" ]; then
            echo "/* #undef $name */"
            printf '%s    "%s": {"kind": "%s"}' "$comma" "$name" "$kind" >> "$checks_json"
        else
            result="$(cat "$result_file")"
            if [ "$result" = true ]; then
                echo "#define $name 1"
            else
                echo "/* #undef $name */"
            fi
            printf '%s    "%s": {"kind": "%s", "ok": %s, "language": "%s"}' "$comma" "$name" "$kind" "$result" "$language" >> "$checks_json"
        fi
        comma=",
"
    done
    echo "#endif"
} > "$config_h"

{
    echo "{"
    echo "  \\"host_triple\\": \\"$host_triple\\","
    echo "  \\"cpu_include_dir\\": \\"$cpu_include_dir\\","
    echo "  \\"os_include_dir\\": \\"$os_include_dir\\","
    echo "  \\"abi_baseline_pair\\": \\"$abi_baseline_pair\\","
    echo "  \\"abi_tweaks_dir\\": \\"$abi_tweaks_dir\\","
    echo "  \\"atomicity_dir\\": \\"$atomicity_dir\\","
    echo "  \\"atomic_word_dir\\": \\"$atomic_word_dir\\","
    echo "  \\"cpu_defines_dir\\": \\"$cpu_defines_dir\\","
    echo "  \\"error_constants_dir\\": \\"$error_constants_dir\\","
    echo "  \\"checks\\": {"
    cat "$checks_json"
    echo
    echo "  }"
    echo "}"
} > "$summary"
""",
        execution_requirements = {"supports-path-mapping": "1"},
        mnemonic = "LibstdcxxConfigProbe",
    )

def _libstdcxx_config_h_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    config_h = ctx.actions.declare_file(ctx.attr.name + ".h")
    summary = ctx.actions.declare_file(ctx.attr.name + ".json")
    template_source = "__libstdcxx_probe_source__.c"
    template_object = "__libstdcxx_probe_output__.o"
    template_binary = "__libstdcxx_probe_binary__"

    compile_templates = {
        "c": _compile_template(
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.c_compile,
            source_file = template_source,
            output_file = template_object,
            user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts + [
                "-Werror=implicit-function-declaration",
            ],
        ),
        "c++": _compile_template(
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.cpp_compile,
            source_file = template_source,
            output_file = template_object,
            user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.cxxopts + [
                "-nostdinc++",
            ],
        ),
    }
    link_template = _link_template(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        output_file = template_binary,
    )

    results = []
    for check in COMPILE_CHECKS:
        results.append(_declare_compile_probe(
            ctx = ctx,
            cc_toolchain = cc_toolchain,
            check = check,
            template = compile_templates[check.language],
            source_placeholder = template_source,
            output_placeholder = template_object,
        ))
    for check in LINK_CHECKS:
        results.append(_declare_link_probe(
            ctx = ctx,
            cc_toolchain = cc_toolchain,
            check = check,
            compile_template = compile_templates[check.language],
            link_template = link_template,
            source_placeholder = template_source,
            object_placeholder = template_object,
            binary_placeholder = template_binary,
        ))
    for policy in POLICY_DEFINES:
        results.append(_policy_result(policy))

    _write_config_outputs(ctx, config_h, summary, results)

    return [
        DefaultInfo(files = depset([config_h, summary])),
        OutputGroupInfo(
            config_h = depset([config_h]),
            summary = depset([summary]),
        ),
    ]

libstdcxx_config_h = rule(
    implementation = _libstdcxx_config_h_impl,
    attrs = {
        "abi_baseline_pair": attr.string(mandatory = True),
        "abi_tweaks_dir": attr.string(mandatory = True),
        "atomic_word_dir": attr.string(mandatory = True),
        "atomicity_dir": attr.string(mandatory = True),
        "cpu_defines_dir": attr.string(mandatory = True),
        "cpu_include_dir": attr.string(mandatory = True),
        "error_constants_dir": attr.string(mandatory = True),
        "host_triple": attr.string(mandatory = True),
        "os_include_dir": attr.string(mandatory = True),
    },
    cfg = config_probe_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
