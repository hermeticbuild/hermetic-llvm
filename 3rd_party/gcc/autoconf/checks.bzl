# Small local autoconf-style check API.
#
# This file intentionally mirrors the shape of external autoconf rulesets:
# source-counterpart files declare checks as JSON-encoded data, execution rules
# consume those declarations, and header rules render the results. Keep this
# generic and free of libstdc++ and libgcc policy.

def _make_check(fields):
    return json.encode(fields)

def _language(language):
    if language == "cpp":
        return "c++"
    return language

def _with_optional(fields, **optional):
    # Leave unset options out, so that checks that do not use them encode as
    # before.
    for key, value in optional.items():
        if value:
            fields[key] = value
    return fields

def compile_check(name, source, language = "c", flags = [], defines_on_success = None, probe_contexts = [], value = "", output_regex = ""):
    """A check that compiles source.

    Args:
      name: The check's name, and its define unless defines_on_success is set.
      source: The source to compile.
      language: "c" or "c++".
      flags: Compile flags added before the source.
      defines_on_success: The macros defined when the check succeeds.
      probe_contexts: Named file sets from autoconf_config that the check uses.
      value: The value of the defines when the check succeeds, instead of 1,
        as for AC_DEFINE_UNQUOTED in a success branch.
      output_regex: An extended regular expression that the compiler's
        assembly output must also match, for checks that grep the output of a
        -S compile. The probe compiles with -S in place of -c.

    Returns:
      The JSON-encoded check.
    """
    if defines_on_success == None:
        defines_on_success = [name]
    return _make_check(_with_optional(
        {
            "defines_on_success": defines_on_success,
            "flags": flags,
            "language": _language(language),
            "name": name,
            "probe_contexts": probe_contexts,
            "source": source.strip() + "\n",
            "type": "compile",
        },
        output_regex = output_regex,
        value = value,
    ))

def link_check(name, source, language = "c++", compile_flags = [], link_flags = [], defines_on_success = None, probe_contexts = [], value = ""):
    if defines_on_success == None:
        defines_on_success = [name]
    return _make_check(_with_optional(
        {
            "compile_flags": compile_flags,
            "defines_on_success": defines_on_success,
            "language": _language(language),
            "link_flags": link_flags,
            "name": name,
            "probe_contexts": probe_contexts,
            "source": source.strip() + "\n",
            "type": "link",
        },
        value = value,
    ))

def compute_int_check(name, expression, prologue = "", language = "c", flags = [], defines_on_success = None, required = False, probe_contexts = []):
    """A check that computes an integer constant expression, like AC_COMPUTE_INT.

    It finds the value without running anything, by the compile-time search
    autoconf uses when cross compiling.

    Args:
      name: The check's name, and its define unless defines_on_success is set.
      expression: An integer constant expression.
      prologue: Source before the test, such as #include lines.
      language: "c" or "c++".
      flags: Compile flags added before the source.
      defines_on_success: The macros defined to the value.
      required: Whether the probe fails when the value cannot be computed, as
        AC_COMPUTE_INT's callers do with AC_MSG_ERROR.
      probe_contexts: Named file sets from autoconf_config that the check uses.

    Returns:
      The JSON-encoded check.
    """
    if defines_on_success == None:
        defines_on_success = [name]
    return _make_check({
        "defines_on_success": defines_on_success,
        "expression": expression,
        "flags": flags,
        "language": _language(language),
        "name": name,
        "probe_contexts": probe_contexts,
        "required": required,
        "source": prologue.strip() + "\n",
        "type": "compute_int",
    })

def ac_check_sizeof(type, prologue = ""):
    """AC_CHECK_SIZEOF: defines SIZEOF_<TYPE> to sizeof (type)."""
    return compute_int_check(
        name = "SIZEOF_" + type.upper().replace(" ", "_").replace("*", "P"),
        expression = "(long int) (sizeof ({}))".format(type),
        prologue = prologue,
        required = True,
    )

def policy_define(name, value = "1", defines_on_success = None):
    if defines_on_success == None:
        defines_on_success = [name]
    return _make_check({
        "defines_on_success": defines_on_success,
        "name": name,
        "type": "define",
        "value": str(value),
    })

def policy_undef(name):
    return _make_check({
        "name": name,
        "type": "undef",
    })

def policy_string_define(name, value):
    return _make_check({
        "name": name,
        "type": "string_define",
        "value": value,
    })

def header_check(header):
    return compile_check(
        name = "HAVE_" + header.upper().replace("/", "_").replace(".", "_"),
        source = """
#include <{header}>
int main(void) {{ return 0; }}
""".format(header = header),
    )

def ac_check_headers(headers):
    return [header_check(header) for header in headers]

def ac_header_stdc():
    """AC_HEADER_STDC: defines STDC_HEADERS when the ISO C headers are usable.

    autoconf compiles a source that includes them, then greps <string.h> and
    <stdlib.h> for memchr and free. This compiles uses of the two instead. It
    skips autoconf's <ctype.h> run test, as autoconf does when cross
    compiling.
    """
    return compile_check(
        name = "STDC_HEADERS",
        source = """
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <float.h>
int main (void) { void *(*m) (const void *, int, size_t) = memchr; void (*f) (void *) = free; return !m || !f; }
""",
    )

def function_link_check(name, header, expression, language = "c++", compile_flags = [], link_flags = [], probe_contexts = []):
    return link_check(
        name = name,
        language = language,
        compile_flags = compile_flags,
        link_flags = link_flags,
        probe_contexts = probe_contexts,
        source = """
#include <{header}>
int main() {{
    {expression};
    return 0;
}}
""".format(header = header, expression = expression),
    )

def AC_TRY_COMPILE(name, code, language = "c", CFLAGS = [], CXXFLAGS = [], define = None, probe_contexts = []):
    return compile_check(
        name = name,
        source = code,
        language = language,
        flags = CXXFLAGS if _language(language) == "c++" else CFLAGS,
        defines_on_success = [define or name],
        probe_contexts = probe_contexts,
    )

def AC_TRY_LINK(name, code, language = "c++", CFLAGS = [], CXXFLAGS = [], LIBS = [], define = None, probe_contexts = []):
    return link_check(
        name = name,
        source = code,
        language = language,
        compile_flags = CXXFLAGS if _language(language) == "c++" else CFLAGS,
        link_flags = LIBS,
        defines_on_success = [define or name],
        probe_contexts = probe_contexts,
    )

def AC_DEFINE(name, value = "1"):
    return policy_define(name, value)

def AC_FAIL(name):
    return policy_undef(name)

def AC_CHECK_HEADERS(headers):
    return ac_check_headers(headers)

checks = struct(
    AC_CHECK_HEADERS = AC_CHECK_HEADERS,
    AC_DEFINE = AC_DEFINE,
    AC_FAIL = AC_FAIL,
    AC_TRY_COMPILE = AC_TRY_COMPILE,
    AC_TRY_LINK = AC_TRY_LINK,
)
