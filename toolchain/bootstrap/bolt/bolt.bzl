"""Linux release binary BOLT optimization."""

load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

LLVMBOLTProfileInfo = provider(
    doc = "BOLT profile collected from an instrumented LLVM binary.",
    fields = {
        "profile": "The BOLT fdata profile.",
    },
)

_BOLT_COMPILE_FLAGS = [
    "-x",
    "c",
    "-O3",
    "-fintegrated-cc1",
    "-fomit-frame-pointer",
    "-ffunction-sections",
    "-fdata-sections",
    "-pthread",
    "-DZSTD_DISABLE_ASM",
    "-DZSTD_MULTITHREAD",
    "-DZSTD_NOBENCH",
    "-DZSTD_NODICT",
    "-DZSTD_NODECOMPRESS",
    "-DZSTD_NOTRACE",
    "-UZSTD_LEGACY_SUPPORT",
    "-DZSTD_LEGACY_SUPPORT=0",
]

_BOLT_OPTIMIZATION_ARGS = [
    "--reorder-blocks=ext-tsp",
    "--reorder-functions=cdsort",
    "--split-functions",
    "--split-all-cold",
    "--split-eh",
    "--dyno-stats",
]

def _instrumentation_runtime_archive(target):
    archives = [
        file
        for file in target[DefaultInfo].files.to_list()
        if file.basename.endswith(".a")
    ]
    pic_archives = [file for file in archives if file.basename.endswith(".pic.a")]
    if len(pic_archives) == 1:
        return pic_archives[0]
    if len(archives) == 1:
        return archives[0]
    fail("expected one BOLT instrumentation runtime archive, got {}".format(archives))

def _training_source(files):
    sources = [file for file in files if file.basename == "zstd_compress.c"]
    if len(sources) != 1:
        fail("expected one zstd_compress.c training source, got {}".format(sources))
    return sources[0]

def _llvm_bolt_binary_impl(ctx):
    binary = ctx.file.binary
    runtime = _instrumentation_runtime_archive(ctx.attr._instrumentation_runtime)
    training_source = _training_source(ctx.files._training_srcs)

    instrumented_binary = ctx.actions.declare_file(ctx.label.name + ".instrumented")
    profile = ctx.actions.declare_file(ctx.label.name + ".fdata")

    instrument_args = ctx.actions.args()
    instrument_args.add(binary)
    instrument_args.add("--instrument")
    instrument_args.add("--instrumentation-file=" + profile.path)
    instrument_args.add("--instrumentation-binpath=" + instrumented_binary.path)
    instrument_args.add("--instrumentation-sleep-time=1")
    instrument_args.add("--instrumentation-no-counters-clear")
    instrument_args.add("--runtime-instrumentation-lib=" + runtime.path)
    instrument_args.add("-o")
    instrument_args.add(instrumented_binary)

    ctx.actions.run(
        executable = ctx.executable._llvm_bolt,
        arguments = [instrument_args],
        inputs = [
            binary,
            runtime,
        ],
        outputs = [instrumented_binary],
        mnemonic = "LLVMBOLTInstrument",
        progress_message = "Instrumenting %{label} with BOLT",
    )

    instrumented_clang = ctx.actions.declare_file(ctx.label.name + ".instrumented_tools/clang")
    ctx.actions.symlink(
        output = instrumented_clang,
        target_file = instrumented_binary,
        is_executable = True,
    )

    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    include_dirs = depset(sorted({
        file.dirname: None
        for file in ctx.files._training_srcs
    }.keys()))
    object_file = ctx.actions.declare_file(ctx.label.name + ".training.o")
    compile_variables = cc_common.create_compile_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        include_directories = include_dirs,
        output_file = object_file.path,
        source_file = training_source.path,
        user_compile_flags = _BOLT_COMPILE_FLAGS,
    )
    compile_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.c_compile,
        variables = compile_variables,
    )
    ctx.actions.run_shell(
        arguments = [
            profile.path,
            instrumented_clang.path,
        ] + cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = ACTION_NAMES.c_compile,
            variables = compile_variables,
        ),
        command = """
profile="$1"
shift
"$@"
status=$?
test "$status" -eq 0 || exit "$status"
previous_size=0
stable_intervals=0
attempt=0
while test "$attempt" -lt 60; do
    sleep 1
    if test -f "$profile"; then
        size=$(wc -c < "$profile")
    else
        size=0
    fi
    if test "$size" -gt 0 && test "$size" -eq "$previous_size"; then
        stable_intervals=$((stable_intervals + 1))
        test "$stable_intervals" -ge 3 && exit 0
    else
        stable_intervals=0
    fi
    previous_size="$size"
    attempt=$((attempt + 1))
done
echo "BOLT profile was not written to $profile" >&2
exit 1
""",
        env = compile_env,
        inputs = depset(
            [
                instrumented_binary,
                instrumented_clang,
                training_source,
            ],
            transitive = [
                cc_toolchain.all_files,
                ctx.attr._training_srcs[DefaultInfo].files,
            ],
        ),
        outputs = [
            object_file,
            profile,
        ],
        mnemonic = "LLVMBOLTProfile",
        progress_message = "Collecting BOLT profile for %{label}",
        toolchain = CC_TOOLCHAIN_TYPE,
    )

    optimized_binary = ctx.actions.declare_file(ctx.label.name + ".unstripped")
    optimize_args = ctx.actions.args()
    optimize_args.add(binary)
    optimize_args.add("--data=" + profile.path)
    optimize_args.add_all(_BOLT_OPTIMIZATION_ARGS)
    optimize_args.add("-o")
    optimize_args.add(optimized_binary)

    ctx.actions.run(
        executable = ctx.executable._llvm_bolt,
        arguments = [optimize_args],
        inputs = [
            binary,
            profile,
        ],
        outputs = [optimized_binary],
        mnemonic = "LLVMBOLTOptimize",
        progress_message = "Optimizing %{label} with BOLT",
    )

    stripped_output = ctx.actions.declare_file(ctx.label.name + ".stripped")
    strip_args = ctx.actions.args()
    strip_args.add("--strip-all")
    strip_args.add("-o")
    strip_args.add(stripped_output)
    strip_args.add(optimized_binary)
    ctx.actions.run(
        executable = ctx.executable._llvm_strip,
        arguments = [strip_args],
        inputs = [optimized_binary],
        outputs = [stripped_output],
        mnemonic = "LLVMBOLTStrip",
        progress_message = "Stripping BOLT output for %{label}",
    )

    verification_binary = ctx.actions.declare_file(ctx.label.name + ".verify_tools/llvm")
    ctx.actions.symlink(
        output = verification_binary,
        target_file = stripped_output,
        is_executable = True,
    )

    output = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.run_shell(
        arguments = [
            verification_binary.path,
            stripped_output.path,
            output.path,
        ],
        command = """
"$1" --version >/dev/null
cp "$2" "$3"
chmod +x "$3"
""",
        inputs = [
            stripped_output,
            verification_binary,
        ],
        outputs = [output],
        mnemonic = "LLVMBOLTVerify",
        progress_message = "Verifying BOLT output for %{label}",
    )

    return [
        DefaultInfo(
            files = depset([output]),
            executable = output,
        ),
        LLVMBOLTProfileInfo(profile = profile),
        OutputGroupInfo(
            bolt_profile = depset([profile]),
        ),
    ]

llvm_bolt_binary = rule(
    implementation = _llvm_bolt_binary_impl,
    executable = True,
    attrs = {
        "binary": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "_instrumentation_runtime": attr.label(
            default = "@llvm-project//bolt:bolt_rt_instr",
            cfg = "exec",
        ),
        "_llvm_bolt": attr.label(
            default = "//toolchain/bootstrap/bolt:llvm-bolt",
            cfg = "exec",
            executable = True,
        ),
        "_llvm_strip": attr.label(
            default = "@llvm-project//llvm:llvm-strip",
            cfg = "exec",
            executable = True,
        ),
        "_training_srcs": attr.label(
            default = "@llvm_fdo_zstd//:zstd_compress_files",
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
