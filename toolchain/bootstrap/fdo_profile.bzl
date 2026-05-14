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

def _single_file(files, attr_name):
    if len(files) != 1:
        fail("expected exactly one file in {}, got {}".format(attr_name, len(files)))
    return files[0]

def _llvm_fdo_profile_data_impl(ctx):
    binary_file = ctx.actions.declare_file(ctx.label.name + ".zstd")
    profraw = ctx.actions.declare_file(ctx.label.name + ".profraw")
    profdata = ctx.actions.declare_file(ctx.label.name + ".profdata")

    target_triple = ctx.attr.target_triple
    if len(target_triple) != 1:
        fail("expected exactly one target triple, got {}".format(target_triple))

    builtin_headers = _single_file(ctx.files.builtin_headers, "builtin_headers")
    crt_objects = _single_file(ctx.files.crt_objects, "crt_objects")
    kernel_headers = _single_file(ctx.files.kernel_headers, "kernel_headers")
    libc_headers = _single_file(ctx.files.libc_headers, "libc_headers")
    libc_library_search = _single_file(ctx.files.libc_library_search, "libc_library_search")
    resource_dir = _single_file(ctx.files.resource_dir, "resource_dir")
    sanitizer_headers = _single_file(ctx.files.sanitizer_headers, "sanitizer_headers")

    include_dirs = {}
    for file in ctx.files.zstd_headers + ctx.files.zstd_srcs:
        include_dirs[file.dirname] = None

    training_args = ctx.actions.args()
    training_args.add("-target")
    training_args.add(target_triple[0])
    training_args.add("-nostdlibinc")
    training_args.add("-isystem")
    training_args.add(kernel_headers.path)
    training_args.add("-isystem")
    training_args.add(libc_headers.path)
    training_args.add_all([
        "-Xclang",
        "-internal-isystem",
        "-Xclang",
        sanitizer_headers.path,
        "-Xclang",
        "-internal-isystem",
        "-Xclang",
        builtin_headers.path,
    ])
    training_args.add_all(_TRAINING_FLAGS)
    training_args.add_all(_LINK_FLAGS)
    training_args.add("-o")
    training_args.add(binary_file)
    training_args.add("-resource-dir")
    training_args.add(resource_dir.path)
    training_args.add("-B" + crt_objects.path)
    training_args.add("-L" + libc_library_search.path)
    training_args.add_all(["-I" + include_dir for include_dir in sorted(include_dirs.keys())])
    training_args.add("-x")
    training_args.add("c")
    training_args.add(ctx.file.src)
    training_args.add_all(ctx.files.zstd_srcs)

    ctx.actions.run(
        executable = ctx.attr.clangxx[DefaultInfo].files_to_run,
        arguments = [training_args],
        env = {"LLVM_PROFILE_FILE": profraw.path},
        inputs = depset(
            direct = [ctx.file.src],
            transitive = [
                ctx.attr.builtin_headers[DefaultInfo].files,
                ctx.attr.crt_objects[DefaultInfo].files,
                ctx.attr.kernel_headers[DefaultInfo].files,
                ctx.attr.libc_headers[DefaultInfo].files,
                ctx.attr.libc_library_search[DefaultInfo].files,
                ctx.attr.resource_dir[DefaultInfo].files,
                ctx.attr.sanitizer_headers[DefaultInfo].files,
                ctx.attr.zstd_headers[DefaultInfo].files,
                ctx.attr.zstd_srcs[DefaultInfo].files,
            ],
        ),
        tools = ctx.files.data,
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
        "data": attr.label_list(
            allow_files = True,
            doc = "Files needed next to the instrumented compiler, such as lld and builtin headers.",
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
        "src": attr.label(
            allow_single_file = [".c"],
            mandatory = True,
        ),
        "target_triple": attr.string_list(
            mandatory = True,
        ),
        "zstd_headers": attr.label(
            allow_files = [".h"],
            mandatory = True,
        ),
        "zstd_srcs": attr.label(
            allow_files = [".c"],
            mandatory = True,
        ),
    },
    cfg = _profile_generation_transition,
)
