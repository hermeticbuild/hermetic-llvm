#!/usr/bin/env bash
#
# Static inventory and audit helper for GCC libstdc++ configure sources. It
# reads fetched GCC files from Bazel runfiles, checks status coverage, and
# verifies that Markdown checklists mention every status-tracked configure
# macro.
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

require_env() {
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      echo "missing required environment variable: ${name}" >&2
      exit 1
    fi
  done
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

write_gcc_defines() {
  output="$1"
  extract_defines > "${output}"
  printf '%s\n' HAVE_FPCLASS HAVE_QFPCLASS >> "${output}"
  sort -u -o "${output}" "${output}"
}

write_gcc_macro_uses() {
  output="$1"
  extract_macro_uses > "${output}"
}

reviewed_check_arguments() {
  extract_check_arguments | awk -F: '
    $1 ~ /^(AC_ARG_ENABLE|AC_ARG_WITH|AC_CHECK_DECL|AC_CHECK_DECLS|AC_CHECK_FUNCS|AC_CHECK_HEADERS|AC_CHECK_TYPE|AC_CHECK_TYPES|AC_COMPUTE_INT)$/ {
      if ($2 != "funclist") {
        print
      }
    }
  ' | sort -u
}

check_status() {
  require_env \
    ACINCLUDE_CHECKS \
    AUTOCONF_CONFIG \
    AUTOCONF_HDR \
    CC_CONFIGURE_PROBE \
    CHECKS \
    CONFIGURE_AC_CHECKS \
    CROSSCONFIG_CHECKS \
    CXXCONFIG_HEADER \
    GTHR_HEADERS \
    LARGEFILE_CONFIG_HEADER \
    LIBSTDCXX_CONFIG_H \
    GCC_CONFIG_CHECKS \
    LINKAGE_CHECKS \
    PROVIDERS \
    TARGET_CONFIG \
    VERSION_SCRIPT

  gcc_defines="${tmp}/gcc-defines.txt"
  gcc_macros="${tmp}/gcc-macros.txt"
  status_defines="${tmp}/status-defines.txt"
  status_macros="${tmp}/status-macros.txt"
  modeled_defines="${tmp}/modeled-defines.txt"
  modeled_macros="${tmp}/modeled-macros.txt"
  invalid_statuses="${tmp}/invalid-statuses.txt"

  write_gcc_defines "${gcc_defines}"
  write_gcc_macro_uses "${gcc_macros}"

  awk -v modeled="${modeled_defines}" -v invalid="${invalid_statuses}" '
BEGIN {
  known["probe-modeled"] = 1
  known["policy-modeled"] = 1
  known["target-derived"] = 1
  known["header-probe"] = 1
  known["build-setting-later"] = 1
  known["intentionally-defaulted"] = 1
  known["not-needed"] = 1
  known["unsupported-feature"] = 1
  known["unsupported-target"] = 1
}
/^[ \t]*(#|$)/ { next }
{
  if (NF < 2 || !known[$2]) {
    print FILENAME ":" FNR ": " $0 > invalid
    next
  }
  print $1
  if ($2 == "probe-modeled" || $2 == "policy-modeled") {
    print $1 > modeled
  }
}
' "${STATUS_FILE}" | sort > "${status_defines}"
  sort -o "${modeled_defines}" "${modeled_defines}"

  awk -v modeled="${modeled_macros}" -v invalid="${invalid_statuses}" '
BEGIN {
  known["modeled"] = 1
  known["target-derived"] = 1
  known["build-setting-later"] = 1
  known["not-needed"] = 1
  known["unsupported-feature"] = 1
  known["unsupported-target"] = 1
}
/^[ \t]*(#|$)/ { next }
{
  if (NF < 2 || !known[$2]) {
    print FILENAME ":" FNR ": " $0 > invalid
    next
  }
  print $1
  if ($2 == "modeled") {
    print $1 > modeled
  }
}
' "${MACRO_STATUS_FILE}" | sort > "${status_macros}"
  sort -o "${modeled_macros}" "${modeled_macros}"

  if [ -s "${invalid_statuses}" ]; then
    cat "${invalid_statuses}" >&2
    exit 1
  fi

  if duplicates="$(uniq -d "${status_defines}")" && [ -n "${duplicates}" ]; then
    echo "duplicate statuses:" >&2
    printf '%s\n' "${duplicates}" >&2
    exit 1
  fi

  if duplicates="$(uniq -d "${status_macros}")" && [ -n "${duplicates}" ]; then
    echo "duplicate macro statuses:" >&2
    printf '%s\n' "${duplicates}" >&2
    exit 1
  fi

  missing_statuses="$(comm -23 "${gcc_defines}" "${status_defines}")"
  if [ -n "${missing_statuses}" ]; then
    echo "missing statuses for GCC defines:" >&2
    printf '%s\n' "${missing_statuses}" >&2
    exit 1
  fi

  unknown_statuses="$(comm -13 "${gcc_defines}" "${status_defines}")"
  if [ -n "${unknown_statuses}" ]; then
    echo "statuses for unknown GCC defines:" >&2
    printf '%s\n' "${unknown_statuses}" >&2
    exit 1
  fi

  missing_macro_statuses="$(comm -23 "${gcc_macros}" "${status_macros}")"
  if [ -n "${missing_macro_statuses}" ]; then
    echo "missing statuses for GCC/libstdc++ configure macro calls:" >&2
    printf '%s\n' "${missing_macro_statuses}" >&2
    exit 1
  fi

  unknown_macro_statuses="$(comm -13 "${gcc_macros}" "${status_macros}")"
  if [ -n "${unknown_macro_statuses}" ]; then
    echo "statuses for unknown GCC/libstdc++ configure macro calls:" >&2
    printf '%s\n' "${unknown_macro_statuses}" >&2
    exit 1
  fi

  missing_models="${tmp}/missing-models.txt"
  : > "${missing_models}"
  while IFS= read -r define; do
    if ! grep -F -q "${define}" \
      "${ACINCLUDE_CHECKS}" \
      "${AUTOCONF_CONFIG}" \
      "${AUTOCONF_HDR}" \
      "${CC_CONFIGURE_PROBE}" \
      "${CHECKS}" \
      "${CONFIGURE_AC_CHECKS}" \
      "${CROSSCONFIG_CHECKS}" \
      "${CXXCONFIG_HEADER}" \
      "${GTHR_HEADERS}" \
      "${LARGEFILE_CONFIG_HEADER}" \
      "${LIBSTDCXX_CONFIG_H}" \
      "${GCC_CONFIG_CHECKS}" \
      "${LINKAGE_CHECKS}" \
      "${PROVIDERS}" \
      "${TARGET_CONFIG}" \
      "${VERSION_SCRIPT}"; then
      printf '%s\n' "${define}" >> "${missing_models}"
    fi
  done < "${modeled_defines}"

  if [ -s "${missing_models}" ]; then
    echo "modeled defines not found in libstdc++ model sources:" >&2
    cat "${missing_models}" >&2
    exit 1
  fi

  missing_macro_models="${tmp}/missing-macro-models.txt"
  : > "${missing_macro_models}"
  while IFS= read -r macro; do
    if ! grep -F -i -q "${macro}" \
      "${ACINCLUDE_CHECKS}" \
      "${AUTOCONF_CONFIG}" \
      "${AUTOCONF_HDR}" \
      "${CC_CONFIGURE_PROBE}" \
      "${CHECKS}" \
      "${CONFIGURE_AC_CHECKS}" \
      "${CROSSCONFIG_CHECKS}" \
      "${CXXCONFIG_HEADER}" \
      "${GTHR_HEADERS}" \
      "${LARGEFILE_CONFIG_HEADER}" \
      "${LIBSTDCXX_CONFIG_H}" \
      "${GCC_CONFIG_CHECKS}" \
      "${LINKAGE_CHECKS}" \
      "${PROVIDERS}" \
      "${TARGET_CONFIG}" \
      "${VERSION_SCRIPT}"; then
      printf '%s\n' "${macro}" >> "${missing_macro_models}"
    fi
  done < "${modeled_macros}"

  if [ -s "${missing_macro_models}" ]; then
    echo "modeled macro calls not found in libstdc++ model sources:" >&2
    cat "${missing_macro_models}" >&2
    exit 1
  fi
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

  while IFS= read -r check_argument; do
    argument="${check_argument#*:}"
    if ! grep -F -q "${argument}" "${AUTOCONF_CHECKS}"; then
      printf 'autoconf.checks.md missing concrete check argument: %s\n' "${check_argument}" >> "${missing}"
    fi
  done < <(reviewed_check_arguments)

  if [ -s "${missing}" ]; then
    cat "${missing}" >&2
    exit 1
  fi
}

case "${mode}" in
  inventory)
    print_inventory
    ;;
  check-status)
    check_status
    ;;
  check-docs)
    check_docs
    ;;
  check-all)
    check_status
    check_docs
    ;;
  *)
    echo "usage: $0 [inventory|check-status|check-docs|check-all]" >&2
    exit 2
    ;;
esac
