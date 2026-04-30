load(":abis.bzl", "UNCONSTRAINED_WINDOWS_ABI", "WINDOWS_ABIS")

def declare_abis_constraints():
    native.constraint_setting(
        name = "abi",
        default_constraint_value = UNCONSTRAINED_WINDOWS_ABI,
    )

    for abi in WINDOWS_ABIS + [UNCONSTRAINED_WINDOWS_ABI]:
        native.constraint_value(
            name = abi,
            constraint_setting = ":abi",
        )
