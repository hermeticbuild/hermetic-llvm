#!/usr/bin/env bash
# Checks libgcc_s.so.1's soname and that it exports exactly the symbols and
# symbol versions of GCC's own build, listed in $EXPECTED_SYMBOLS.

set -euo pipefail

resolve_runfile() {
  local path="$1"
  if [[ -e "$path" ]]; then
    printf '%s\n' "$path"
  elif [[ -n "${RUNFILES_DIR:-}" && -e "${RUNFILES_DIR}/${path}" ]]; then
    printf '%s\n' "${RUNFILES_DIR}/${path}"
  elif [[ -n "${RUNFILES_DIR:-}" && -e "${RUNFILES_DIR}/_main/${path}" ]]; then
    printf '%s\n' "${RUNFILES_DIR}/_main/${path}"
  else
    printf '%s\n' "$path"
  fi
}

shared="$(resolve_runfile "${LIBGCC_S:?}")"
expected="$(resolve_runfile "${EXPECTED_SYMBOLS:?}")"
readelf="$(resolve_runfile "${READELF:?}")"

soname="$("$readelf" -d "$shared" | sed -n 's/.*Library soname: \[\(.*\)\]/\1/p')"
if [[ "$soname" != "libgcc_s.so.1" ]]; then
  echo "unexpected soname: '$soname'" >&2
  exit 1
fi

# Defined dynamic symbols with their versions, without lld's absent version
# node symbols or GNU ld's GCC_x.y@@GCC_x.y ones. The section index and name
# are read from the end of the line, since readelf adds an Other column for
# AArch64's [VARIANT_PCS] functions.
actual="$(mktemp)"
trap 'rm -f "$actual"' EXIT
"$readelf" --dyn-syms -W "$shared" \
  | awk 'NR > 3 && $5 != "LOCAL" && $(NF - 1) != "UND" { print $NF }' \
  | grep -v '^GCC_[0-9.]*@@' \
  | LC_ALL=C sort -u > "$actual"

if ! diff -u "$expected" "$actual"; then
  echo "libgcc_s.so.1 exports differ from GCC's" >&2
  exit 1
fi
