"""Build the intrinsic modules with the matching Flang executable."""

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

def _flang_modules_impl(ctx):
    outputs = [ctx.actions.declare_file(ctx.label.name + "/" + name + ".mod") for name in _MODULES]
    output_dir = outputs[0].dirname

    args = ctx.actions.args()
    args.add("--target=" + ctx.attr.target_triple)
    args.add("-fsyntax-only")
    args.add("-module-dir", output_dir)
    args.add("-I", output_dir)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable._flang,
        arguments = [args],
        inputs = ctx.files.srcs + ctx.files.hdrs,
        outputs = outputs,
        mnemonic = "FlangIntrinsicModules",
        tools = [ctx.attr._flang[DefaultInfo].files_to_run],
    )

    return [DefaultInfo(files = depset(outputs))]

flang_modules = rule(
    implementation = _flang_modules_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".f90"], mandatory = True),
        "hdrs": attr.label_list(allow_files = [".h"]),
        "target_triple": attr.string(mandatory = True),
        "_flang": attr.label(
            default = "@llvm-project//flang/tools/flang-driver:flang",
            executable = True,
            cfg = "exec",
        ),
    },
)

FLANG_MODULE_SOURCES = [
    "@llvm-project//flang-rt/lib/runtime:" + name + ".f90"
    for name in _MODULES
]
