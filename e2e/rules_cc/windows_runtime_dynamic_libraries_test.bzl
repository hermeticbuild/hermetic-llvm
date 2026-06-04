def _windows_runtime_dynamic_libraries_test_impl(ctx):
    output_groups = ctx.attr.target[OutputGroupInfo]
    runtime_libraries = getattr(output_groups, "runtime_dynamic_libraries", None)
    if runtime_libraries == None:
        fail("missing runtime_dynamic_libraries output group")

    binary = ctx.attr.target[DefaultInfo].files_to_run.executable
    if binary == None:
        fail("target does not expose an executable")

    actual = [file.path for file in runtime_libraries.to_list()]
    expected = [binary.dirname + "/" + ctx.attr.runtime_library_basename]
    if actual != expected:
        fail("expected runtime_dynamic_libraries to be %s, got %s" % (expected, actual))

    marker = ctx.actions.declare_file(ctx.label.name + ".ok")
    ctx.actions.write(marker, "ok\n")
    return [DefaultInfo(files = depset([marker]))]

windows_runtime_dynamic_libraries_assertion = rule(
    implementation = _windows_runtime_dynamic_libraries_test_impl,
    attrs = {
        "runtime_library_basename": attr.string(mandatory = True),
        "target": attr.label(providers = [OutputGroupInfo], mandatory = True),
    },
)
