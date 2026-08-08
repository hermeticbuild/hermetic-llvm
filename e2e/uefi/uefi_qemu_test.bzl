"""End-to-end UEFI test backed by the rules_qemu system toolchain."""

load("@rules_python//python:py_test.bzl", "py_test")

_QEMU_SYSTEM_TOOLCHAIN_TYPE = Label("@rules_qemu//qemu:exec_toolchain_type")

def _qemu_system_target_impl(_ctx):
    return []

qemu_system_target = rule(
    implementation = _qemu_system_target_impl,
    build_setting = config.string(flag = True),
)

def _runfiles_path(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    return "{}/{}".format(ctx.workspace_name, file.short_path)

def _uefi_qemu_config_impl(ctx):
    qemu = ctx.toolchains[_QEMU_SYSTEM_TOOLCHAIN_TYPE]
    application = ctx.attr.application[DefaultInfo]
    executable = application.files_to_run.executable
    config = ctx.actions.declare_file(ctx.label.name + ".json")

    ctx.actions.write(
        output = config,
        content = json.encode_indent({
            "application": _runfiles_path(ctx, executable),
            "machine": qemu.machine,
            "qemu_system": _runfiles_path(ctx, qemu.qemu_system),
            "system_data_anchor": _runfiles_path(ctx, qemu.system_data_anchor),
            "system_target": qemu.system_target,
        }),
    )

    runfiles = ctx.runfiles(
        files = [
            config,
            executable,
            qemu.qemu_system,
            qemu.system_data_anchor,
        ],
        transitive_files = qemu.system_data_files,
    ).merge(application.default_runfiles)

    return [DefaultInfo(files = depset([config]), runfiles = runfiles)]

_uefi_qemu_config = rule(
    implementation = _uefi_qemu_config_impl,
    attrs = {
        "application": attr.label(cfg = "target", executable = True, mandatory = True),
    },
    toolchains = [_QEMU_SYSTEM_TOOLCHAIN_TYPE],
)

def uefi_qemu_test(name, *, application, **kwargs):
    config_name = name + "_config"
    config_kwargs = {}
    if "target_compatible_with" in kwargs:
        config_kwargs["target_compatible_with"] = kwargs["target_compatible_with"]

    _uefi_qemu_config(
        name = config_name,
        application = application,
        testonly = True,
        **config_kwargs
    )

    py_test(
        name = name,
        srcs = ["uefi_qemu_test.py"],
        args = ["$(rlocationpath :{})".format(config_name)],
        config_settings = {
            "@rules_python//python/config_settings:bootstrap_impl": "script",
        },
        data = [":{}".format(config_name)],
        deps = ["@rules_python//python/runfiles"],
        main = "uefi_qemu_test.py",
        python_version = "3.12",
        **kwargs
    )
