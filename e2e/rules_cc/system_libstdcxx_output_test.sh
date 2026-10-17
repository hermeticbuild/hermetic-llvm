#!/usr/bin/env bash
set -euo pipefail

dynamic="$($READELF --dynamic "$BINARY")"
grep -Fq 'Shared library: [libstdc++.so.6]' <<< "$dynamic"
grep -Fq 'Shared library: [libgcc_s.so.1]' <<< "$dynamic"
if grep -Fq 'Shared library: [libunwind' <<< "$dynamic"; then
  echo "system GNU runtime mode must not link the LLVM exception unwinder" >&2
  exit 1
fi
exec "$BINARY"
