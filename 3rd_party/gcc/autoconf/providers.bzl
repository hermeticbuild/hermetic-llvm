AutoconfResultInfo = provider(
    doc = "The fields needed to render one configure result.",
    fields = {
        "defines_on_success": "list[str]: defines emitted when the check succeeds",
        "kind": "str: compile, link, define, string_define, or undef",
        "name": "str: check name",
        "result": "File or None: compile/link result file",
        "value": "str: value for a policy define, empty for other checks",
    },
)

AutoconfConfigInfo = provider(
    doc = "Ordered autoconf-style check results for generated configuration headers.",
    fields = {
        "results": "list[AutoconfResultInfo]: ordered compile, link, and policy results",
    },
)
