"""Build target intrinsic modules with the matching execution Flang."""

_MODULES = [
    "__fortran_builtins",
    "__fortran_ieee_exceptions",
    "__fortran_type_info",
    "flang_debug",
    "iso_fortran_env_impl",
    "iso_fortran_env",
    "ieee_arithmetic",
    "ieee_exceptions",
    "ieee_features",
    "iso_c_binding",
]

FLANG_MODULE_SOURCES = [
    "@llvm-project//flang-rt/lib/runtime:" + name + ".f90"
    for name in _MODULES
]

def _intrinsic_modules_impl(ctx):
    if len(ctx.attr.target_triple) != 1:
        fail("Expected one LLVM target triple for Flang intrinsic modules")

    modules = [ctx.actions.declare_file(ctx.label.name + "/" + name + ".mod") for name in _MODULES]
    module_dir = modules[0].dirname

    args = ctx.actions.args()
    args.add("--target=" + ctx.attr.target_triple[0])
    args.add("-fsyntax-only")
    args.add("-module-dir", module_dir)
    args.add("-I", module_dir)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable.compiler,
        arguments = [args],
        inputs = ctx.files.srcs + ctx.files.hdrs,
        outputs = modules,
        mnemonic = "FlangIntrinsicModules",
        tools = [ctx.attr.compiler[DefaultInfo].files_to_run],
    )

    return [DefaultInfo(files = depset(modules))]

intrinsic_modules = rule(
    implementation = _intrinsic_modules_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".f90"], mandatory = True),
        "hdrs": attr.label_list(allow_files = [".h"]),
        "target_triple": attr.string_list(mandatory = True),
        "compiler": attr.label(
            default = "@llvm-project//flang/tools/flang-driver:flang",
            executable = True,
            allow_single_file = True,
            cfg = "exec",
        ),
    },
)
