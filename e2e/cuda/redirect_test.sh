#!/usr/bin/env bash
set -euo pipefail
driver="$1"
redirect="$2"
raw="$3"
cpu_only="$4"
"$driver" reject "$redirect" "$raw" "$TEST_TMPDIR/negative"
if "$redirect" "$cpu_only" "$TEST_TMPDIR/cpu.o" __cuda_payload_test 2>"$TEST_TMPDIR/cpu.err"; then
  echo "Incorrectly accepted a source without device registration" >&2
  exit 1
fi
grep -q 'no CUDA device registration' "$TEST_TMPDIR/cpu.err"
test ! -e "$TEST_TMPDIR/cpu.o"
