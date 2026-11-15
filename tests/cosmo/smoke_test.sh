#!/bin/sh
set -eu

ape="$TEST_SRCDIR/$TEST_WORKSPACE/tests/cosmo/smoke.com"
test "$(head -c 8 "$ape")" = "MZqFpD='"
export TMPDIR="$TEST_TMPDIR"
before=$(cksum < "$ape")
/bin/sh "$ape"
test "$(cksum < "$ape")" = "$before"
