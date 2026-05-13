#!/usr/bin/env bash
#
# Audits the libstdc++ config define port against GCC's configure sources.
# The checked-in status file must classify every AC_DEFINE from GCC's
# libstdc++-v3/acinclude.m4, configure.ac, crossconfig.m4, and selected
# top-level GCC config macros, so GCC updates fail until new configure
# decisions are reviewed and either modeled or intentionally tracked.
set -euo pipefail

tmp="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/libstdcxx-config-audit.$$"
mkdir -p "${tmp}"
trap 'rm -rf "${tmp}"' EXIT

gcc_defines="${tmp}/gcc-defines.txt"
gcc_macros="${tmp}/gcc-macros.txt"
status_defines="${tmp}/status-defines.txt"
status_macros="${tmp}/status-macros.txt"
modeled_defines="${tmp}/modeled-defines.txt"
modeled_macros="${tmp}/modeled-macros.txt"
invalid_statuses="${tmp}/invalid-statuses.txt"

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
}
{
  line = $0
  sub(/^[ \t\[]+/, "", line)
  if (line ~ /^(#|dnl([ \t]|$))/) {
    next
  }
  emit_defines($0)
}
' \
  "${GCC_ACINCLUDE}" \
  "${GCC_CONFIGURE_AC}" \
  "${GCC_CROSSCONFIG}" \
  "${GCC_CONFIG_ACX}" \
  "${GCC_CONFIG_CET}" \
  "${GCC_CONFIG_FUTEX}" \
  "${GCC_CONFIG_GCXXFILT}" \
  "${GCC_CONFIG_GTHR}" \
  "${GCC_CONFIG_HWCAPS}" \
  "${GCC_CONFIG_ICONV}" \
  "${GCC_CONFIG_LTHOSTFLAGS}" \
  "${GCC_CONFIG_MULTI}" \
  "${GCC_CONFIG_NO_EXECUTABLES}" \
  "${GCC_CONFIG_TLS}" \
  "${GCC_CONFIG_TOOLEXECLIBDIR}" \
  "${GCC_CONFIG_UNWIND_IPINFO}" \
  | sort -u > "${gcc_defines}"

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
{
  process($0)
}
' \
  "${GCC_ACINCLUDE}" \
  "${GCC_CONFIGURE_AC}" \
  "${GCC_CROSSCONFIG}" \
  | sort -u > "${gcc_macros}"

awk -v modeled="${modeled_defines}" -v invalid="${invalid_statuses}" '
BEGIN {
  known["modeled"] = 1
  known["target-derived"] = 1
  known["header-probe"] = 1
  known["build-setting-later"] = 1
  known["intentionally-defaulted"] = 1
  known["unsupported"] = 1
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
' "${STATUS_FILE}" | sort > "${status_defines}"
sort -o "${modeled_defines}" "${modeled_defines}"

awk -v modeled="${modeled_macros}" -v invalid="${invalid_statuses}" '
BEGIN {
  known["modeled"] = 1
  known["target-derived"] = 1
  known["build-setting-later"] = 1
  known["not-needed"] = 1
  known["unsupported"] = 1
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
    "${CONFIG_PROBE}" \
    "${CONFIGURE_AC_CHECKS}" \
    "${CONFIGURE}" \
    "${CROSSCONFIG_CHECKS}" \
    "${HEADERS}" \
    "${NATIVE_AUTOCONF_CHECKS}" \
    "${SYMBOLS}"; then
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
    "${CONFIG_PROBE}" \
    "${CONFIGURE_AC_CHECKS}" \
    "${CONFIGURE}" \
    "${CROSSCONFIG_CHECKS}" \
    "${HEADERS}" \
    "${NATIVE_AUTOCONF_CHECKS}" \
    "${SYMBOLS}"; then
    printf '%s\n' "${macro}" >> "${missing_macro_models}"
  fi
done < "${modeled_macros}"

if [ -s "${missing_macro_models}" ]; then
  echo "modeled macro calls not found in libstdc++ model sources:" >&2
  cat "${missing_macro_models}" >&2
  exit 1
fi
