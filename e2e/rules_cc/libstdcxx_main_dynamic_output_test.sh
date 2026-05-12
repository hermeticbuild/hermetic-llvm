#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="Hello, World!"

BIN="$BINARY"

if [[ ! -x "$BIN" && -n "${RUNFILES_DIR:-}" ]]; then
  if [[ -x "${RUNFILES_DIR}/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/${BIN}"
  elif [[ -x "${RUNFILES_DIR}/_main/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/_main/${BIN}"
  fi
fi

if [[ ! -x "$BIN" ]]; then
  echo "libstdc++ dynamic binary is not executable: ${BIN}"
  exit 1
fi

set +e
OUTPUT="$("${BIN}" 2>&1)"
STATUS="$?"
set -e

if [[ "$STATUS" -ne 0 ]]; then
  echo "libstdc++ dynamic binary failed with exit code ${STATUS}: ${BIN}"
  echo
  echo "---- Output ----"
  printf '%s\n' "$OUTPUT"
  echo "----------------"
  exit "$STATUS"
fi

trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" != "$(trim "$EXPECTED_OUTPUT")" ]]; then
  echo "libstdc++ dynamic output does not match expected string."
  echo
  echo "---- Expected ----"
  printf '%s\n' "$EXPECTED_OUTPUT"
  echo "---- Got ----"
  printf '%s\n' "$OUTPUT"
  echo "------------------"
  exit 1
fi
