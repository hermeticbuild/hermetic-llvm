#!/usr/bin/env bash

set -euo pipefail

resolve_runfile() {
  local path="$1"

  if [[ -e "$path" ]]; then
    printf '%s\n' "$path"
    return
  fi

  if [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]]; then
    local manifest_path
    manifest_path="$(awk -v path="$path" '$1 == path { print $2; exit }' "${RUNFILES_MANIFEST_FILE}")"
    if [[ -n "$manifest_path" ]]; then
      printf '%s\n' "$manifest_path"
      return
    fi
  fi

  if [[ -n "${RUNFILES_DIR:-}" ]]; then
    if [[ -e "${RUNFILES_DIR}/${path}" ]]; then
      printf '%s\n' "${RUNFILES_DIR}/${path}"
      return
    elif [[ -e "${RUNFILES_DIR}/_main/${path}" ]]; then
      printf '%s\n' "${RUNFILES_DIR}/_main/${path}"
      return
    fi
  fi

  printf '%s\n' "$path"
}

shared="$(resolve_runfile "${LIBSTDCXX_SHARED:?}")"
soname="$(resolve_runfile "${LIBSTDCXX_SHARED_SONAME:?}")"
linker_name="$(resolve_runfile "${LIBSTDCXX_SHARED_LINKER_NAME:?}")"
readelf="$(resolve_runfile "${READELF:?}")"

if [[ ! -x "$readelf" ]]; then
  echo "llvm-readelf is not executable: ${readelf}"
  exit 1
fi

dynamic="${TEST_TMPDIR}/dynamic.txt"
versions="${TEST_TMPDIR}/versions.txt"

"${readelf}" -d "${shared}" > "${dynamic}"
grep -F "Library soname: [libstdc++.so.6]" "${dynamic}" >/dev/null

"${readelf}" --version-info "${shared}" > "${versions}"
grep -F "Version definition section '.gnu.version_d'" "${versions}" >/dev/null
grep -F "Name: GLIBCXX_3.4" "${versions}" >/dev/null
grep -F "Name: CXXABI_1.3" "${versions}" >/dev/null

"${readelf}" -h "${soname}" >/dev/null
"${readelf}" -h "${linker_name}" >/dev/null

[[ "${LIBSTDCXX_SHARED_SONAME:?}" == *"/libstdc++.so.6" ]]
[[ "${LIBSTDCXX_SHARED_LINKER_NAME:?}" == *"/libstdc++.so" ]]
