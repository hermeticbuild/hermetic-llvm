#!/usr/bin/env bash
#
# Audits the libstdc++ config define port against GCC's configure sources.
# The checked-in status file must classify every AC_DEFINE from GCC's
# libstdc++-v3/acinclude.m4 and configure.ac, so GCC updates fail until new
# configure decisions are reviewed and either modeled or intentionally tracked.
set -euo pipefail

tmp="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/libstdcxx-config-audit.$$"
mkdir -p "${tmp}"
trap 'rm -rf "${tmp}"' EXIT

gcc_defines="${tmp}/gcc-defines.txt"
status_defines="${tmp}/status-defines.txt"
modeled_defines="${tmp}/modeled-defines.txt"
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
    if (token !~ /\$/ && token ~ /^([A-Z_]|__)/) {
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
' "${GCC_ACINCLUDE}" "${GCC_CONFIGURE_AC}" | sort -u > "${gcc_defines}"

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

if [ -s "${invalid_statuses}" ]; then
  cat "${invalid_statuses}" >&2
  exit 1
fi

if duplicates="$(uniq -d "${status_defines}")" && [ -n "${duplicates}" ]; then
  echo "duplicate statuses:" >&2
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

missing_models="${tmp}/missing-models.txt"
: > "${missing_models}"
while IFS= read -r define; do
  if ! grep -F -q "${define}" \
    "${CONFIG_CHECKS}" \
    "${CONFIG_PROBE}" \
    "${CONFIGURE}" \
    "${HEADERS}" \
    "${SYMBOLS}"; then
    printf '%s\n' "${define}" >> "${missing_models}"
  fi
done < "${modeled_defines}"

if [ -s "${missing_models}" ]; then
  echo "modeled defines not found in libstdc++ model sources:" >&2
  cat "${missing_models}" >&2
  exit 1
fi
