#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d "${DSYM_BUNDLE}" ]]; then
  echo "missing dSYM bundle: ${DSYM_BUNDLE}" >&2
  exit 1
fi

dwarf_file="${DSYM_BUNDLE}/Contents/Resources/DWARF/${DWARF_FILE}"
if [[ ! -f "${dwarf_file}" ]]; then
  echo "missing dSYM DWARF file: ${dwarf_file}" >&2
  exit 1
fi

if [[ ! -s "${dwarf_file}" ]]; then
  echo "empty dSYM DWARF file: ${dwarf_file}" >&2
  exit 1
fi
