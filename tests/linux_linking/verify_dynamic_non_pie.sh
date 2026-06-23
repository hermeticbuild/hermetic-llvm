#!/usr/bin/env bash
# Verifies that the given binary is a dynamically linked, non-PIE ELF.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <readelf> <binary>" >&2
  exit 2
fi

readelf=$1
binary=$2

if [[ ! -x "$readelf" ]]; then
  echo "FAIL: readelf $readelf is not executable" >&2
  exit 1
fi

if [[ ! -e "$binary" ]]; then
  echo "FAIL: $binary does not exist" >&2
  exit 1
fi

header=$("$readelf" -h "$binary")
if ! grep -qE "Type:[[:space:]]+EXEC" <<<"$header"; then
  echo "FAIL: $binary is PIE or not executable type (ELF type != EXEC)" >&2
  echo "$header" >&2
  exit 1
fi

segments=$("$readelf" -l "$binary")
if ! grep -qE "INTERP" <<<"$segments"; then
  echo "FAIL: $binary has no PT_INTERP segment (not dynamically linked)" >&2
  echo "$segments" >&2
  exit 1
fi

echo "OK: $binary is dynamic non-PIE"
