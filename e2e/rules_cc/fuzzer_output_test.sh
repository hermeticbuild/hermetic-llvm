#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="hello"

BIN="$BINARY"
if [[ ! -x "$BIN" && -n "${RUNFILES_DIR:-}" ]]; then
  if [[ -x "${RUNFILES_DIR}/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/${BIN}"
  elif [[ -x "${RUNFILES_DIR}/_main/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/_main/${BIN}"
  fi
fi

echo "Using binary: ${BIN}"
ls -l "${BIN}" 2>/dev/null || true

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

CORPUS_DIR="${TMPDIR}/corpus"
mkdir "${CORPUS_DIR}"
printf '%s' "${EXPECTED_OUTPUT}" >"${CORPUS_DIR}/seed"

OUTPUT="${TMPDIR}/observed.txt"
LLVM_FUZZER_OUTPUT="${OUTPUT}" "${BIN}" -runs=1 "${CORPUS_DIR}"

# Strip trailing newlines for consistency
trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

OBSERVED="$(cat "${OUTPUT}")"
if [[ "$(trim "$OBSERVED")" == "$(trim "$EXPECTED_OUTPUT")" ]]; then
  echo "Fuzzer output matches expected string."
else
  echo "Fuzzer output does not match expected string."
  echo
  echo "---- Expected ----"
  printf '%s\n' "$EXPECTED_OUTPUT"
  echo "---- Got ----"
  printf '%s\n' "$OBSERVED"
  echo "------------------"
  exit 1
fi
