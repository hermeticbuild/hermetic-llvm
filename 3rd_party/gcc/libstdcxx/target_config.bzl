# Mirrors the host-derived directory choices from GCC's
# libstdc++-v3/configure.host. When adding a target or changing one of these
# fields, compare against configure.host plus configure.ac's *_SRCDIR
# substitutions for the generated include/source paths.

load("//3rd_party/gcc:version.bzl", "libstdcxx_has_atomic_lock_policy_define")
load("//3rd_party/gcc/libstdcxx/autoconf:checks.bzl", "policy_define", "policy_undef")

_SUPPORTED_TARGETS = {
    "//platforms/config:linux_x86_64_gnu": {
        "abi_baseline_pair": "x86_64-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/i486",
        "error_constants_dir": "os/generic",
        "host_triple": "x86_64-linux-gnu",
        "locale_dir": "locale/gnu",
        "os_include_dir": "os/gnu-linux",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_aarch64_gnu": {
        "abi_baseline_pair": "aarch64-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/aarch64",
        "error_constants_dir": "os/generic",
        "host_triple": "aarch64-linux-gnu",
        "locale_dir": "locale/gnu",
        "os_include_dir": "os/gnu-linux",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_armv7_gnu": {
        "abi_baseline_pair": "armv7-linux-gnueabihf",
        "abi_tweaks_dir": "cpu/arm",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/arm",
        "cpu_opt_dir": "cpu/generic/opt",
        "error_constants_dir": "os/generic",
        "host_triple": "armv7-linux-gnueabihf",
        "locale_dir": "locale/gnu",
        "os_include_dir": "os/gnu-linux",
        "port_symver_files": ["os/gnu-linux/arm-eabi-extra.ver"],
        "ptrdiff_t_is_int": True,
        "size_t_is_uint": True,
        "size_t_mangling": "j",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_riscv64_gnu": {
        "abi_baseline_pair": "riscv64-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": False,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/generic",
        "error_constants_dir": "os/generic",
        "host_triple": "riscv64-linux-gnu",
        "locale_dir": "locale/gnu",
        "os_include_dir": "os/gnu-linux",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_s390x_gnu": {
        "abi_baseline_pair": "s390x-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/generic",
        "error_constants_dir": "os/generic",
        "host_triple": "s390x-linux-gnu",
        "locale_dir": "locale/gnu",
        "os_include_dir": "os/gnu-linux",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_x86_64_musl": {
        "abi_baseline_pair": "x86_64-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/i486",
        "error_constants_dir": "os/generic",
        "host_triple": "x86_64-linux-musl",
        "locale_dir": "locale/generic",
        "os_include_dir": "os/generic",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_aarch64_musl": {
        "abi_baseline_pair": "aarch64-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/aarch64",
        "error_constants_dir": "os/generic",
        "host_triple": "aarch64-linux-musl",
        "locale_dir": "locale/generic",
        "os_include_dir": "os/generic",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_armv7_musl": {
        "abi_baseline_pair": "armv7-linux-musleabihf",
        "abi_tweaks_dir": "cpu/arm",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/arm",
        "cpu_opt_dir": "cpu/generic/opt",
        "error_constants_dir": "os/generic",
        "host_triple": "armv7-linux-musleabihf",
        "locale_dir": "locale/generic",
        "os_include_dir": "os/generic",
        "port_symver_files": ["os/gnu-linux/arm-eabi-extra.ver"],
        "ptrdiff_t_is_int": True,
        "size_t_is_uint": True,
        "size_t_mangling": "j",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_riscv64_musl": {
        "abi_baseline_pair": "riscv64-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": False,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/generic",
        "error_constants_dir": "os/generic",
        "host_triple": "riscv64-linux-musl",
        "locale_dir": "locale/generic",
        "os_include_dir": "os/generic",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:linux_s390x_musl": {
        "abi_baseline_pair": "s390x-linux-gnu",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/generic",
        "error_constants_dir": "os/generic",
        "host_triple": "s390x-linux-musl",
        "locale_dir": "locale/generic",
        "os_include_dir": "os/generic",
        "symver_file": "abi/pre/gnu.ver",
        "symver_style": "gnu",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:windows_x86_64": {
        "abi_baseline_pair": "x86_64-mingw32",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/i486",
        "error_constants_dir": "os/mingw32-w64",
        "host_triple": "x86_64-w64-mingw32",
        "locale_dir": "locale/generic",
        "os_include_dir": "os/mingw32-w64",
        "thread_header": "gthr-posix.h",
    },
    "//platforms/config:windows_aarch64": {
        "abi_baseline_pair": "aarch64-mingw32",
        "abi_tweaks_dir": "cpu/generic",
        "atomic_lock_policy": True,
        "atomic_word_dir": "cpu/generic",
        "atomicity_dir": "cpu/generic/atomicity_builtins",
        "cpu_defines_dir": "cpu/generic",
        "cpu_include_dir": "cpu/aarch64",
        "error_constants_dir": "os/mingw32-w64",
        "host_triple": "aarch64-w64-mingw32",
        "locale_dir": "locale/generic",
        "os_include_dir": "os/mingw32-w64",
        "thread_header": "gthr-posix.h",
    },
}

_DEFAULT_POLICY_FIELDS = {
    "enable_float128": False,
    "extern_template": 1,
    "have_attribute_visibility": 1,
    "inline_version": 0,
    "port_symver_files": [],
    "ptrdiff_t_is_int": False,
    "size_t_is_uint": False,
    "size_t_mangling": "m",
    "symver_file": "abi/pre/none.ver",
    "symver_style": "none",
    "use_allocator_new": 1,
    "use_cxx11_abi": 1,
    "use_dual_abi": 1,
}

_NO_MATCH_ERROR = "Unsupported libstdc++ target platform"

def _select_for_targets(project):
    return select({
        Label(config): project(values)
        for config, values in _SUPPORTED_TARGETS.items()
    }, no_match_error = _NO_MATCH_ERROR)

def libstdcxx_host_triple():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["host_triple"])

def libstdcxx_cpu_include_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["cpu_include_dir"])

def libstdcxx_os_include_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["os_include_dir"])

def libstdcxx_abi_baseline_pair():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["abi_baseline_pair"])

def libstdcxx_abi_tweaks_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["abi_tweaks_dir"])

def libstdcxx_atomicity_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["atomicity_dir"])

def libstdcxx_atomic_word_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["atomic_word_dir"])

def libstdcxx_atomic_lock_policy():
    # type: () -> select[bool]
    return _select_for_targets(lambda values: values["atomic_lock_policy"])

def libstdcxx_cpu_defines_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["cpu_defines_dir"])

def libstdcxx_error_constants_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["error_constants_dir"])

def libstdcxx_locale_dir():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["locale_dir"])

def libstdcxx_thread_header():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values["thread_header"])

def libstdcxx_enable_float128():
    # type: () -> select[bool]
    return _select_for_targets(lambda values: values.get("enable_float128", _DEFAULT_POLICY_FIELDS["enable_float128"]))

def libstdcxx_extern_template():
    # type: () -> select[int]
    return _select_for_targets(lambda values: values.get("extern_template", _DEFAULT_POLICY_FIELDS["extern_template"]))

def libstdcxx_have_attribute_visibility():
    # type: () -> select[int]
    return _select_for_targets(lambda values: values.get("have_attribute_visibility", _DEFAULT_POLICY_FIELDS["have_attribute_visibility"]))

def libstdcxx_inline_version():
    # type: () -> select[int]
    return _select_for_targets(lambda values: values.get("inline_version", _DEFAULT_POLICY_FIELDS["inline_version"]))

def libstdcxx_use_allocator_new():
    # type: () -> select[int]
    return _select_for_targets(lambda values: values.get("use_allocator_new", _DEFAULT_POLICY_FIELDS["use_allocator_new"]))

def libstdcxx_use_cxx11_abi():
    # type: () -> select[int]
    return _select_for_targets(lambda values: values.get("use_cxx11_abi", _DEFAULT_POLICY_FIELDS["use_cxx11_abi"]))

def libstdcxx_use_dual_abi():
    # type: () -> select[int]
    return _select_for_targets(lambda values: values.get("use_dual_abi", _DEFAULT_POLICY_FIELDS["use_dual_abi"]))

def libstdcxx_symver_style():
    # type: () -> select[str]
    return _select_for_targets(lambda values: values.get("symver_style", _DEFAULT_POLICY_FIELDS["symver_style"]))

def _config_h_policy_defines(values, gcc_version):
    # type: (_Target, str) -> list[str]
    return (
        ([
            policy_define("_GLIBCXX_SYMVER"),
            policy_define("_GLIBCXX_SYMVER_GNU"),
            policy_define("HAVE_AS_SYMVER_DIRECTIVE"),
            policy_define("HAVE_SYMVER_SYMBOL_RENAMING_RUNTIME_SUPPORT"),
            policy_define("HAVE_EXCEPTION_PTR_SINCE_GCC46"),
        ] if values.get("symver_style", _DEFAULT_POLICY_FIELDS["symver_style"]) == "gnu" else []) +
        ([policy_define("HAVE_ATOMIC_LOCK_POLICY")] if libstdcxx_has_atomic_lock_policy_define(gcc_version) and values["atomic_lock_policy"] else []) +
        [policy_define("_GLIBCXX_MANGLE_SIZE_T", values.get("size_t_mangling", _DEFAULT_POLICY_FIELDS["size_t_mangling"]))] +
        ([
            policy_define("_GLIBCXX_PTRDIFF_T_IS_INT"),
        ] if values.get("ptrdiff_t_is_int", _DEFAULT_POLICY_FIELDS["ptrdiff_t_is_int"]) else [
            policy_undef("_GLIBCXX_PTRDIFF_T_IS_INT"),
        ]) +
        ([
            policy_define("_GLIBCXX_SIZE_T_IS_UINT"),
        ] if values.get("size_t_is_uint", _DEFAULT_POLICY_FIELDS["size_t_is_uint"]) else [
            policy_undef("_GLIBCXX_SIZE_T_IS_UINT"),
        ])
    )

def libstdcxx_config_h_policy_defines(gcc_version):
    # type: (str) -> select[list[str]]
    return _select_for_targets(lambda values: _config_h_policy_defines(values, gcc_version))

# These adapters turn configure.host-style directory fields into the exact
# config headers and sources consumed by libstdc++-v3/include/Makefile.am and
# libstdc++-v3/src/*/Makefile.am.
def _gcc_config_file(values, field, basename):
    # type: (_Target, _DirectoryField, str) -> str
    if field == "cpu_opt_dir":
        directory = values.get(field, "{}/opt".format(values["cpu_include_dir"]))
    else:
        directory = values[field]
    return "libstdc++-v3/config/{}/{}".format(directory, basename)

def _gcc_config_file_label(field, basename):
    # type: (_DirectoryField, str) -> select[str]
    return _select_for_targets(lambda values: _gcc_config_file(values, field, basename))

def libstdcxx_ctype_base_h():
    # type: () -> select[str]
    return _gcc_config_file_label("os_include_dir", "ctype_base.h")

def libstdcxx_ctype_inline_h():
    # type: () -> select[str]
    return _gcc_config_file_label("os_include_dir", "ctype_inline.h")

def libstdcxx_os_defines_h():
    # type: () -> select[str]
    return _gcc_config_file_label("os_include_dir", "os_defines.h")

def libstdcxx_atomic_word_h():
    # type: () -> select[str]
    return _gcc_config_file_label("atomic_word_dir", "atomic_word.h")

def libstdcxx_atomicity_h():
    # type: () -> select[str]
    return _gcc_config_file_label("atomicity_dir", "atomicity.h")

def libstdcxx_cxxabi_tweaks_h():
    # type: () -> select[str]
    return _gcc_config_file_label("abi_tweaks_dir", "cxxabi_tweaks.h")

def libstdcxx_cpu_defines_h():
    # type: () -> select[str]
    return _gcc_config_file_label("cpu_defines_dir", "cpu_defines.h")

def libstdcxx_error_constants_h():
    # type: () -> select[str]
    return _gcc_config_file_label("error_constants_dir", "error_constants.h")

def libstdcxx_bits_opt_random_h():
    # type: () -> select[str]
    return _gcc_config_file_label("cpu_opt_dir", "bits/opt_random.h")

def libstdcxx_ext_opt_random_h():
    # type: () -> select[str]
    return _gcc_config_file_label("cpu_opt_dir", "ext/opt_random.h")

def libstdcxx_c_locale_h():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "c_locale.h")

def libstdcxx_c_locale_internal_h():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "c++locale_internal.h")

def libstdcxx_messages_members_h():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "messages_members.h")

def libstdcxx_time_members_h():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "time_members.h")

def libstdcxx_ctype_configure_char_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("os_include_dir", "ctype_configure_char.cc")

def libstdcxx_c_locale_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "c_locale.cc")

def libstdcxx_codecvt_members_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "codecvt_members.cc")

def libstdcxx_collate_members_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "collate_members.cc")

def libstdcxx_ctype_members_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "ctype_members.cc")

def libstdcxx_messages_members_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "messages_members.cc")

def libstdcxx_monetary_members_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "monetary_members.cc")

def libstdcxx_numeric_members_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "numeric_members.cc")

def libstdcxx_time_members_cc():
    # type: () -> select[str]
    return _gcc_config_file_label("locale_dir", "time_members.cc")

def libstdcxx_thread_header_h():
    # type: () -> select[str]
    return _select_for_targets(lambda values: "libgcc/{}".format(values["thread_header"]))

def libstdcxx_symver_file():
    # type: () -> select[str]
    return _select_for_targets(lambda values: "libstdc++-v3/config/{}".format(values.get("symver_file", _DEFAULT_POLICY_FIELDS["symver_file"])))

def libstdcxx_port_symver_files():
    # type: () -> select[list[str]]
    return _select_for_targets(lambda values: [
        "libstdc++-v3/config/{}".format(path)
        for path in values.get("port_symver_files", _DEFAULT_POLICY_FIELDS["port_symver_files"])
    ])
