#!/usr/bin/env bash
#
# Static inventory helper for GCC libstdc++ configure sources. It reads the
# fetched GCC files from Bazel runfiles and checks that the Markdown checklists
# mention every status-tracked configure macro.
set -euo pipefail

mode="${1:-inventory}"

required_env=(
  GCC_ACINCLUDE
  GCC_LINKAGE
  GCC_CONFIGURE_AC
  GCC_CONFIGURE_HOST
  GCC_CROSSCONFIG
  GCC_CONFIG_ACX
  GCC_CONFIG_CET
  GCC_CONFIG_FUTEX
  GCC_CONFIG_GCXXFILT
  GCC_CONFIG_GTHR
  GCC_CONFIG_HWCAPS
  GCC_CONFIG_ICONV
  GCC_CONFIG_LTHOSTFLAGS
  GCC_CONFIG_MULTI
  GCC_CONFIG_NO_EXECUTABLES
  GCC_CONFIG_TLS
  GCC_CONFIG_TOOLEXECLIBDIR
  GCC_CONFIG_UNWIND_IPINFO
  STATUS_FILE
  MACRO_STATUS_FILE
)

for name in "${required_env[@]}"; do
  if [ -z "${!name:-}" ]; then
    echo "missing required environment variable: ${name}" >&2
    exit 1
  fi
done

all_sources=(
  "${GCC_ACINCLUDE}"
  "${GCC_LINKAGE}"
  "${GCC_CONFIGURE_AC}"
  "${GCC_CONFIGURE_HOST}"
  "${GCC_CROSSCONFIG}"
  "${GCC_CONFIG_ACX}"
  "${GCC_CONFIG_CET}"
  "${GCC_CONFIG_FUTEX}"
  "${GCC_CONFIG_GCXXFILT}"
  "${GCC_CONFIG_GTHR}"
  "${GCC_CONFIG_HWCAPS}"
  "${GCC_CONFIG_ICONV}"
  "${GCC_CONFIG_LTHOSTFLAGS}"
  "${GCC_CONFIG_MULTI}"
  "${GCC_CONFIG_NO_EXECUTABLES}"
  "${GCC_CONFIG_TLS}"
  "${GCC_CONFIG_TOOLEXECLIBDIR}"
  "${GCC_CONFIG_UNWIND_IPINFO}"
)

macro_use_sources=(
  "${GCC_ACINCLUDE}"
  "${GCC_LINKAGE}"
  "${GCC_CONFIGURE_AC}"
  "${GCC_CROSSCONFIG}"
)

tmp="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/libstdcxx-autoconf-inventory.$$"
mkdir -p "${tmp}"
trap 'rm -rf "${tmp}"' EXIT

extract_macro_defs() {
  awk '
    match($0, /AC_DEFUN\(\[?[A-Za-z_][A-Za-z0-9_]+/) {
      token = substr($0, RSTART, RLENGTH)
      sub(/^AC_DEFUN\(\[?/, "", token)
      print token
    }
  ' "${all_sources[@]}" | sort -u
}

extract_macro_uses() {
  awk '
    function emit_macro(name) {
      if (name ~ /^(GLIBCXX|GCC)_[A-Z0-9_]+$/) {
        print name
      }
    }
    function process(line) {
      sub(/dnl.*/, "", line)
      sub(/#.*/, "", line)
      if (line ~ /AC_DEFUN[ \t]*\(/) {
        return
      }
      if (match(line, /^[ \t]*(GLIBCXX|GCC)_[A-Z0-9_]+([ \t]*(\(|$|\[))/)) {
        token = substr(line, RSTART, RLENGTH)
        sub(/^[ \t]*/, "", token)
        sub(/[ \t]*(\(|\[)?$/, "", token)
        emit_macro(token)
      }
      while (match(line, /(AC_REQUIRE|AC_BEFORE)\(\[?(GLIBCXX|GCC)_[A-Z0-9_]+/)) {
        token = substr(line, RSTART, RLENGTH)
        sub(/^(AC_REQUIRE|AC_BEFORE)\(\[?/, "", token)
        emit_macro(token)
        line = substr(line, RSTART + RLENGTH)
      }
      while (match(line, /(GLIBCXX|GCC)_[A-Z0-9_]+[ \t]*\(/)) {
        token = substr(line, RSTART, RLENGTH)
        sub(/[ \t]*\($/, "", token)
        emit_macro(token)
        line = substr(line, RSTART + RLENGTH)
      }
    }
    { process($0) }
  ' "${macro_use_sources[@]}" | sort -u
}

extract_defines() {
  awk '
    function trim(s) {
      sub(/^[ \t\[]+/, "", s)
      sub(/[ \t\],].*$/, "", s)
      return s
    }
    function emit_defines(line) {
      while (match(line, /AC_DEFINE(_UNQUOTED)?[ \t]*\(?[ \t]*\[?[A-Za-z_][A-Za-z0-9_$]*/)) {
        token = substr(line, RSTART, RLENGTH)
        sub(/^AC_DEFINE(_UNQUOTED)?[ \t]*\(?[ \t]*\[?/, "", token)
        token = trim(token)
        if (token != "AS_TR_CPP" && token !~ /\$/ && token ~ /^([A-Z_]|__)/) {
          print token
        }
        line = substr(line, RSTART + RLENGTH)
      }
      while (match(line, /AH_VERBATIM\(\[?[A-Za-z_][A-Za-z0-9_]*/)) {
        token = substr(line, RSTART, RLENGTH)
        sub(/^AH_VERBATIM\(\[?/, "", token)
        token = trim(token)
        if (token ~ /^([A-Z_]|__)/) {
          print token
        }
        line = substr(line, RSTART + RLENGTH)
      }
    }
    {
      line = $0
      sub(/^[ \t\[]+/, "", line)
      if (line ~ /^(#|dnl([ \t]|$))/) {
        next
      }
      emit_defines($0)
    }
  ' "${all_sources[@]}" | sort -u
}

extract_check_forms() {
  awk '
    match($0, /(AC_CHECK_HEADERS|AC_CHECK_FUNCS|AC_CHECK_DECLS?|AC_CHECK_TYPES?|AC_COMPILE_IFELSE|AC_LINK_IFELSE|AC_RUN_IFELSE|AC_COMPUTE_INT|AC_SUBST|AM_CONDITIONAL|GLIBCXX_CONDITIONAL|AC_ARG_ENABLE|AC_ARG_WITH)/) {
      token = substr($0, RSTART, RLENGTH)
      print token
    }
  ' "${all_sources[@]}" | sort | uniq -c | awk '{ print $2 " " $1 }'
}

status_symbols() {
  awk '/^[ \t]*(#|$)/ { next } { print $1 }' "$1" | sort -u
}

print_inventory() {
  echo "# Macro definitions"
  extract_macro_defs
  echo
  echo "# Macro uses"
  extract_macro_uses
  echo
  echo "# Config defines"
  extract_defines
  echo
  echo "# Check form counts"
  extract_check_forms
  echo
  echo "# Check arguments"
  extract_check_arguments
}

extract_check_arguments() {
  awk '
    function trim(s) {
      gsub(/\\\n/, " ", s)
      gsub(/\\\\/, " ", s)
      gsub(/^[ \t\r\n]+/, "", s)
      gsub(/[ \t\r\n]+$/, "", s)
      return s
    }
    function normalize_arg(s) {
      s = trim(s)
      gsub(/^\[/, "", s)
      gsub(/\]$/, "", s)
      gsub(/^"/, "", s)
      gsub(/"$/, "", s)
      gsub(/^'\''/, "", s)
      gsub(/'\''$/, "", s)
      return trim(s)
    }
    function first_arg(text,    start, i, c, depth, arg) {
      start = index(text, "(")
      if (!start) {
        return ""
      }
      depth = 0
      arg = ""
      for (i = start + 1; i <= length(text); ++i) {
        c = substr(text, i, 1)
        if (c == "[") {
          depth++
          arg = arg c
        } else if (c == "]") {
          if (depth > 0) {
            depth--
          }
          arg = arg c
        } else if ((c == "," || c == ")") && depth == 0) {
          return normalize_arg(arg)
        } else {
          arg = arg c
        }
      }
      return ""
    }
    function emit_items(kind, arg,    n, i, items, item) {
      arg = normalize_arg(arg)
      if (arg == "") {
        return
      }
      gsub(/\[/, " ", arg)
      gsub(/\]/, " ", arg)
      gsub(/,/, " ", arg)
      n = split(arg, items, /[ \t\r\n]+/)
      for (i = 1; i <= n; ++i) {
        item = items[i]
        gsub(/^[`"'\''()]+/, "", item)
        gsub(/[`"'\''()]+$/, "", item)
        if (item == "" || item ~ /^dnl$/ || item ~ /^#/ || item ~ /^\$/) {
          continue
        }
        if (item ~ /^[A-Za-z0-9_./+-]+$/) {
          print kind ":" item
        }
      }
    }
    function scan_buffer(    arg) {
      arg = first_arg(buffer)
      if (arg == "") {
        return 0
      }
      emit_items(kind, arg)
      buffer = ""
      kind = ""
      collecting = 0
      return 1
    }
    {
      line = $0
      sub(/dnl.*/, "", line)
      if (!collecting) {
        if (match(line, /(AC_CHECK_HEADERS|AC_CHECK_FUNCS|AC_CHECK_DECLS?|AC_CHECK_TYPES?|AC_COMPUTE_INT|AC_SUBST|AM_CONDITIONAL|GLIBCXX_CONDITIONAL|AC_ARG_ENABLE|AC_ARG_WITH)[ \t]*\(/)) {
          kind = substr(line, RSTART, RLENGTH)
          sub(/[ \t]*\($/, "", kind)
          buffer = substr(line, RSTART)
          collecting = 1
          scan_buffer()
        }
      } else {
        buffer = buffer "\n" line
        scan_buffer()
      }
    }
  ' "${all_sources[@]}" | sort -u
}

check_docs() {
  : "${AUTOCONF_CHECKS:?missing AUTOCONF_CHECKS}"
  : "${AUTOCONF_USAGE:?missing AUTOCONF_USAGE}"
  : "${AUTOCONF_README:?missing AUTOCONF_README}"

  missing="${tmp}/missing-docs.txt"
  : > "${missing}"

  while IFS= read -r macro; do
    if ! grep -F -q "${macro}" "${AUTOCONF_CHECKS}"; then
      printf 'autoconf.checks.md missing macro: %s\n' "${macro}" >> "${missing}"
    fi
    if ! grep -F -q "${macro}" "${AUTOCONF_USAGE}"; then
      printf 'autoconf.usage.md missing macro: %s\n' "${macro}" >> "${missing}"
    fi
    if ! grep -F -q "${macro}" "${AUTOCONF_README}"; then
      printf 'autoconf.README.md missing macro: %s\n' "${macro}" >> "${missing}"
    fi
  done < <(status_symbols "${MACRO_STATUS_FILE}")

  if [ -s "${missing}" ]; then
    cat "${missing}" >&2
    exit 1
  fi
}

case "${mode}" in
  inventory)
    print_inventory
    ;;
  check-docs)
    check_docs
    ;;
  *)
    echo "usage: $0 [inventory|check-docs]" >&2
    exit 2
    ;;
esac
