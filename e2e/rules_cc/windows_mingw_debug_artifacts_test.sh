#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }
f=
set -e
# --- end runfiles.bash initialization v3 ---

set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

resolve() {
  local key="${1//\\//}"
  local path
  path="$(rlocation "${key}")"
  [[ -e "${path}" ]] || fail "missing runfile: ${key}"
  printf '%s\n' "${path}"
}

LLVM_READOBJ="$(resolve "${LLVM_READOBJ}")"

executable=
pdb=
for key in ${ARTIFACTS}; do
  artifact="$(resolve "${key}")"
  case "${artifact}" in
    *.exe) executable="${artifact}" ;;
    *.pdb) pdb="${artifact}" ;;
  esac
done

[[ -n "${executable}" ]] || fail "missing executable"
[[ -n "${pdb}" ]] || fail "missing PDB"

"${LLVM_READOBJ}" --coff-debug-directory "${executable}" |
  grep -Fq "PDBFileName: $(basename "${pdb}")" ||
  fail "executable does not reference its PDB by name"
for artifact in "${executable}" "${pdb}"; do
  if grep -a -Fq execroot "${artifact}"; then
    fail "absolute path into the execution root in ${artifact}"
  fi
done
