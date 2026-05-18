"""Rules for generating an LLVM bootstrap FDO profile."""

load("@rules_cc//cc/private/rules_impl/fdo:fdo_profile.bzl", "FdoProfileInfo")
load(":transition_settings.bzl", "LLVM_TOOLS", "SANITIZER_FLAGS", "disable_sanitizers")

_TRAINING_FLAGS = [
    "-O3",
    "-flto=thin",
    "-fomit-frame-pointer",
    "-ffunction-sections",
    "-fdata-sections",
    "-DZSTD_DISABLE_ASM",
    "-DZSTD_MULTITHREAD",
    "-DZSTD_NOBENCH",
    "-DZSTD_NODICT",
    "-DZSTD_NODECOMPRESS",
    "-DZSTD_NOTRACE",
    "-UZSTD_LEGACY_SUPPORT",
    "-DZSTD_LEGACY_SUPPORT=0",
]

_LINK_FLAGS = [
    "--sysroot=/dev/null",
    "-fuse-ld=lld",
    "-rtlib=compiler-rt",
    "-nostdlib++",
    "--unwindlib=none",
    "-Wl,-no-as-needed",
    "-Wl,-z,relro,-z,now",
    "-Wl,--push-state",
    "-Wl,--as-needed",
    "-lpthread",
    "-ldl",
    "-Wl,--pop-state",
    "-Wl,--gc-sections",
    "-Wl,--icf=safe",
    "-pthread",
]

def _profile_generation_transition_impl(settings, attr):
    transition_settings = {
        "//command_line_option:fdo_profile": None,
        "//command_line_option:platforms": str(attr.platform),
        "//toolchain:runtime_stage": "complete",
        "//toolchain:source": "prebuilt",
        "@llvm-project//llvm:driver-tools": LLVM_TOOLS,
    }

    disable_sanitizers(transition_settings)

    return transition_settings

_profile_generation_transition = transition(
    implementation = _profile_generation_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:fdo_profile",
        "//command_line_option:platforms",
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm-project//llvm:driver-tools",
    ] + SANITIZER_FLAGS,
)

def _add_internal_isystem(args, dirs):
    for directory in dirs:
        args.add_all(["-Xclang", "-internal-isystem", "-Xclang"])
        args.add_all([directory], expand_directories = False)

def _c_sources(files):
    return [file for file in files if file.extension == "c"]

def _llvm_fdo_profile_data_impl(ctx):
    binary_file = ctx.actions.declare_file(ctx.label.name + ".zstd")
    profraw = ctx.actions.declare_file(ctx.label.name + ".profraw")
    profdata = ctx.actions.declare_file(ctx.label.name + ".profdata")

    target_triple = ctx.attr.target_triple
    if len(target_triple) != 1:
        fail("expected exactly one target triple, got {}".format(target_triple))

    include_dirs = {}
    for file in ctx.files._zstd_files:
        include_dirs[file.dirname] = None

    training_args = ctx.actions.args()
    training_args.add("-target")
    training_args.add(target_triple[0])
    training_args.add("-nostdlibinc")
    training_args.add_all(ctx.files.kernel_headers, before_each = "-isystem", expand_directories = False)
    training_args.add_all(ctx.files.libc_headers, before_each = "-isystem", expand_directories = False)
    _add_internal_isystem(training_args, ctx.files.sanitizer_headers)
    _add_internal_isystem(training_args, ctx.files.builtin_headers)
    training_args.add_all(_TRAINING_FLAGS)
    training_args.add_all(_LINK_FLAGS)
    training_args.add("-o")
    training_args.add(binary_file)
    training_args.add_all(ctx.files.resource_dir, before_each = "-resource-dir", expand_directories = False)
    training_args.add_all(ctx.files.crt_objects, format_each = "-B%s", expand_directories = False)
    training_args.add_all(ctx.files.libc_library_search, format_each = "-L%s", expand_directories = False)
    training_args.add_all(["-I" + include_dir for include_dir in sorted(include_dirs.keys())])
    training_args.add("-x")
    training_args.add("c")
    training_args.add_all(_c_sources(ctx.files._zstd_files))

    ctx.actions.run(
        executable = ctx.attr.clangxx[DefaultInfo].files_to_run,
        arguments = [training_args],
        env = {"LLVM_PROFILE_FILE": profraw.path},
        inputs = depset(
            transitive = [
                ctx.attr.builtin_headers[DefaultInfo].files,
                ctx.attr.crt_objects[DefaultInfo].files,
                ctx.attr.kernel_headers[DefaultInfo].files,
                ctx.attr.libc_headers[DefaultInfo].files,
                ctx.attr.libc_library_search[DefaultInfo].files,
                ctx.attr.resource_dir[DefaultInfo].files,
                ctx.attr.sanitizer_headers[DefaultInfo].files,
                ctx.attr._zstd_files[DefaultInfo].files,
            ],
        ),
        tools = [ctx.file.linker],
        outputs = [
            binary_file,
            profraw,
        ],
        mnemonic = "LLVMFDOProfileRaw",
        progress_message = "Generating raw LLVM FDO profile with %{label}",
        execution_requirements = {"supports-path-mapping": "1"},
    )

    merge_args = ctx.actions.args()
    merge_args.add("merge")
    merge_args.add("--output")
    merge_args.add(profdata)
    merge_args.add(profraw)

    ctx.actions.run(
        executable = ctx.executable.llvm_profdata,
        arguments = [merge_args],
        inputs = [profraw],
        tools = [
            ctx.attr.llvm_profdata[DefaultInfo].files_to_run,
        ],
        outputs = [profdata],
        mnemonic = "LLVMFDOProfileMerge",
        progress_message = "Merging LLVM FDO profile for %{label}",
        execution_requirements = {"supports-path-mapping": "1"},
    )

    return [
        DefaultInfo(files = depset([profdata])),
        FdoProfileInfo(
            artifact = profdata,
            proto_profile_artifact = None,
            memprof_artifact = None,
        ),
    ]

llvm_fdo_profile_data = rule(
    implementation = _llvm_fdo_profile_data_impl,
    attrs = {
        "builtin_headers": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "clangxx": attr.label(
            executable = True,
            cfg = "target",
            mandatory = True,
            doc = "Instrumented clang++ driver used to collect the profile.",
        ),
        "crt_objects": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "linker": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Instrumented ld.lld used by the clang driver through -fuse-ld=lld.",
        ),
        "llvm_profdata": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "target",
            mandatory = True,
            doc = "Uninstrumented llvm-profdata used to merge raw profiles.",
        ),
        "kernel_headers": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "libc_headers": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "libc_library_search": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "platform": attr.label(
            default = Label("//:rbe_platform"),
            doc = "Execution/target platform used for the training binary.",
        ),
        "resource_dir": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "sanitizer_headers": attr.label(
            allow_files = True,
            mandatory = True,
        ),
        "target_triple": attr.string_list(
            mandatory = True,
        ),
        "_zstd_files": attr.label(
            allow_files = [".c", ".h"],
            default = Label("@llvm_fdo_zstd//:zstd_compress_files"),
        ),
    },
    cfg = _profile_generation_transition,
)
