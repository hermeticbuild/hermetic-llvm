#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="ERROR: AddressSanitizer: heap-use-after-free on address"

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

set +e
OUTPUT="$($BIN 2>&1)"
STATUS=$?
set -e

# Strip trailing newlines for consistency
trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" == *"$(trim "$EXPECTED_OUTPUT")"* ]]; then
  echo "✅ Asan output contains expected string."
else
  echo "❌ Asan output does not contain expected string."
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
