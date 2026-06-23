#!/usr/bin/env bash
# Verifies that the given binary is a static-pie ELF: ELF type DYN (PIE)
# and no PT_INTERP program header (no dynamic linker = statically linked).
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
if ! grep -qE "Type:[[:space:]]+DYN" <<<"$header"; then
  echo "FAIL: $binary is not PIE (ELF type != DYN)" >&2
  echo "$header" >&2
  exit 1
fi

segments=$("$readelf" -l "$binary")
if grep -qE "INTERP" <<<"$segments"; then
  echo "FAIL: $binary has a PT_INTERP segment (not statically linked)" >&2
  echo "$segments" >&2
  exit 1
fi

echo "OK: $binary is static-pie"
