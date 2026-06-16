#!/usr/bin/env bash
set -euo pipefail

if [[ ! -s "${DWP}" ]]; then
  echo "missing or empty fission debug package: ${DWP}" >&2
  exit 1
fi

for section in .debug_cu_index .debug_info.dwo; do
  if ! LC_ALL=C grep -a -F -q "${section}" "${DWP}"; then
    echo "fission debug package is missing ${section}: ${DWP}" >&2
    exit 1
  fi
done
