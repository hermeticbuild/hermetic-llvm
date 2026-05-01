#!/usr/bin/env bash
set -euo pipefail

BIN="$BINARY"

resolve_runfile() {
  local path="$1"
  local -a candidates=("$path")

  if [[ "$path" != *.exe ]]; then
    candidates+=("${path}.exe")
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [[ -n "${RUNFILES_DIR:-}" ]]; then
    local normalized
    for candidate in "${candidates[@]}"; do
      normalized="${candidate//\\//}"
      if [[ -x "${RUNFILES_DIR}/${normalized}" ]]; then
        printf '%s\n' "${RUNFILES_DIR}/${normalized}"
        return 0
      fi
      if [[ -x "${RUNFILES_DIR}/_main/${normalized}" ]]; then
        printf '%s\n' "${RUNFILES_DIR}/_main/${normalized}"
        return 0
      fi
    done
  fi

  if [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]]; then
    local key value
    while IFS= read -r line; do
      key="${line%% *}"
      value="${line#* }"
      for candidate in "${candidates[@]}"; do
        candidate="${candidate//\\//}"
        if [[ "$key" == "$candidate" || "$key" == "_main/$candidate" ]]; then
          printf '%s\n' "$value"
          return 0
        fi
      done
    done <"${RUNFILES_MANIFEST_FILE}"
  fi

  return 1
}

if ! BIN="$(resolve_runfile "$BIN")"; then
  echo "could not resolve runfile: ${BINARY}" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

PROFRAW="${TMPDIR}/profile.profraw"
LLVM_PROFILE_FILE="${PROFRAW}" "${BIN}"

if [[ ! -s "${PROFRAW}" ]]; then
  echo "instrumented binary did not produce a non-empty .profraw file" >&2
  exit 1
fi
