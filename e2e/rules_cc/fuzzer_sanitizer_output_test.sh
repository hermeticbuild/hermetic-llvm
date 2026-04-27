#!/usr/bin/env bash
set -euo pipefail

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

INPUT="${TMPDIR}/seed"
printf '%s' "${INPUT_TEXT}" >"${INPUT}"

set +e
OUTPUT="$("${BIN}" "${INPUT}" 2>&1)"
STATUS=$?
set -e

# Strip trailing newlines for consistency
trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" == *"$(trim "$EXPECTED_OUTPUT")"* ]]; then
  echo "Fuzzer sanitizer output contains expected string."
else
  echo "Fuzzer sanitizer output does not contain expected string."
  echo
  echo "---- Expected ----"
  printf '%s\n' "$EXPECTED_OUTPUT"
  echo "---- Got ----"
  printf '%s\n' "$OUTPUT"
  echo "------------------"
  if [[ ${STATUS:-1} -ne 0 ]]; then
    exit "$STATUS"
  fi
  exit 1
fi

if [[ "${EXPECT_NONZERO:-0}" == "1" && ${STATUS:-0} -eq 0 ]]; then
  echo "Fuzzer sanitizer run was expected to fail, but exited successfully."
  exit 1
fi
