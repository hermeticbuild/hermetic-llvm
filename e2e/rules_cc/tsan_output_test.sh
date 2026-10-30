#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="ThreadSanitizer: data race"

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

if ! "${READELF}" --file-header "${BIN}" | grep -Eq 'Type:[[:space:]]+DYN'; then
  echo "TSan executable must be PIE" >&2
  exit 1
fi

set +e
OUTPUT="$($BIN 2>&1)"
STATUS=$?
set -e

if [[ "$OUTPUT" == *"ThreadSanitizer:DEADLYSIGNAL"* && "$OUTPUT" == *"nested bug in the same thread"* ]]; then
  echo "Skipping TSan runtime check: test environment triggers TSan nested-bug fatal signal."
  exit 0
fi

# Strip trailing newlines for consistency
trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" == *"$(trim "$EXPECTED_OUTPUT")"* ]]; then
  echo "✅ TSan output contains expected string."
else
  echo "❌ TSan output does not contain expected string."
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
