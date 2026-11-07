# TODO(https://github.com/bazelbuild/bazel/issues/32207): Declare field types on the providers.
AutoconfResultInfo = provider(
    doc = "The fields needed to render one configure result.",
    fields = {
        "defines_on_success": "list[str]: defines emitted when the check succeeds",  # type: list[str]
        "kind": "str: compile, link, define, string_define, or undef",  # type: str
        "name": "str: check name",  # type: str
        "result": "File or None: compile/link result file",  # type: File | None
        "value": "str: value for a policy define, empty for other checks",  # type: str
    },
)

AutoconfConfigInfo = provider(
    doc = "Ordered autoconf-style check results for generated configuration headers.",
    fields = {
        "results": "list[AutoconfResultInfo]: ordered compile, link, and policy results",  # type: list[AutoconfResultInfo]
    },
)
