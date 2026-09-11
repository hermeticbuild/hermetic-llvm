#!/usr/bin/env bash

# Checks that libgcc_s.so.1 advertises itself the way GCC's libgcc_s.so.1 of
# the selected GCC version does: the soname, one definition per version node,
# the versions and versioned symbols expected for that GCC version, none of the
# versions later GCC releases introduced, and every exported symbol carrying a
# version.

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

shared="$(resolve_runfile "${LIBGCC_S_SHARED:?}")"
readelf="$(resolve_runfile "${READELF:?}")"

if [[ ! -x "$readelf" ]]; then
  echo "llvm-readelf is not executable: ${readelf}"
  exit 1
fi

[[ "${LIBGCC_S_SHARED:?}" == *"/libgcc_s.so.1" ]]

dynamic="${TEST_TMPDIR}/dynamic.txt"
versions="${TEST_TMPDIR}/versions.txt"
symbols="${TEST_TMPDIR}/symbols.txt"

"${readelf}" -d "${shared}" > "${dynamic}"
grep -F "Library soname: [libgcc_s.so.1]" "${dynamic}" >/dev/null
if grep -F "Shared library: [libunwind.so.1]" "${dynamic}" >/dev/null; then
  echo "libgcc_s.so.1 must not depend on libunwind.so.1"
  exit 1
fi

"${readelf}" --version-info "${shared}" > "${versions}"
grep -F "Version definition section '.gnu.version_d'" "${versions}" >/dev/null
defined="$(sed -n '/Version definition section/,/Version needs section/p' "${versions}" \
  | grep -oE 'Name: (GCC|GLIBC)_[0-9.]+' | sed 's/Name: //')"

duplicates="$(sort <<<"${defined}" | uniq -d || true)"
if [[ -n "${duplicates}" ]]; then
  echo "duplicate version definitions:"
  echo "${duplicates}"
  exit 1
fi

for version in ${EXPECTED_VERSIONS:?}; do
  grep -qx "${version}" <<<"${defined}" || {
    echo "missing version definition: ${version}"
    echo "${defined}"
    exit 1
  }
done

for version in ${FORBIDDEN_VERSIONS:-}; do
  if grep -qx "${version}" <<<"${defined}"; then
    echo "unexpected version definition: ${version}"
    exit 1
  fi
done

"${readelf}" --dyn-syms "${shared}" > "${symbols}"

for symbol in ${EXPECTED_SYMBOLS:?}; do
  grep -F " ${symbol}" "${symbols}" >/dev/null || {
    echo "missing exported symbol: ${symbol}"
    exit 1
  }
done

# Every exported function and object carries a version.
unversioned="$(awk '($4 == "FUNC" || $4 == "OBJECT") && $5 != "LOCAL" && $7 != "UND" && $7 != "ABS" && $8 !~ /@(GCC|GLIBC)_/ { print $8 }' "${symbols}")"
if [[ -n "${unversioned}" ]]; then
  echo "exported symbols without a version:"
  echo "${unversioned}"
  exit 1
fi
