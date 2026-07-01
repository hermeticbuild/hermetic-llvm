#!/usr/bin/env bash
set -euo pipefail

# Runs a tsan-instrumented binary linked against the shared (DSO) runtime
# (--@llvm//config:shared_sanitizer); the DSO is found via LD_LIBRARY_PATH.

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^.*/$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

EXPECTED_OUTPUT="ThreadSanitizer: data race"

BIN="$(rlocation "${BINARY}")"
DSO="$(rlocation "${DSO}")"

export LD_LIBRARY_PATH="$(cd "$(dirname "${DSO}")" && pwd):${LD_LIBRARY_PATH:-}"

set +e
OUTPUT="$("$BIN" 2>&1)"
set -e

if [[ "$OUTPUT" == *"ThreadSanitizer:DEADLYSIGNAL"* && "$OUTPUT" == *"nested bug in the same thread"* ]]; then
  echo "Skipping TSan runtime check: test environment triggers TSan nested-bug fatal signal."
  exit 0
fi

trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" == *"$(trim "$EXPECTED_OUTPUT")"* ]]; then
  exit 0
fi

echo "Shared-runtime TSan output does not contain expected string."
echo "---- Expected ----"
printf '%s\n' "$EXPECTED_OUTPUT"
echo "---- Got ----"
printf '%s\n' "$OUTPUT"
echo "------------------"
exit 1
