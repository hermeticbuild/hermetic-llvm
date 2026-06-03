def _macos_minimum_os_version_info_impl(ctx):
    value = ctx.fragments.apple.macos_minimum_os_flag
    if value == None:
        value = "14.0"
    else:
        value = str(value)

    return [
        platform_common.TemplateVariableInfo({
            "VERSION": value,
        }),
    ]

macos_minimum_os_version_info = rule(
    implementation = _macos_minimum_os_version_info_impl,
    fragments = ["apple"],
)
