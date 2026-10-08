#!/usr/bin/env bash

# Checks that a binary does not depend on any of the given shared libraries:
# the toolchain kept the static C++ runtime for it.

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <readelf> <binary> <not-needed>..." >&2
  exit 2
fi

readelf="$1"
binary="$2"
shift 2

if [[ ! -x "$readelf" ]]; then
  echo "FAIL: readelf $readelf is not executable" >&2
  exit 1
fi

dynamic="$("$readelf" -d "$binary")"
for needed in "$@"; do
  if grep -qF "Shared library: [$needed]" <<<"$dynamic"; then
    echo "FAIL: $binary depends on $needed" >&2
    echo "$dynamic" >&2
    exit 1
  fi
done

echo "OK: $binary keeps the static C++ runtime"
