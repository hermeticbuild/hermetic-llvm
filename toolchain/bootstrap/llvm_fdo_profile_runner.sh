#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 7 ]]; then
  echo "usage: $0 <clang++> <llvm-profdata> <profdata> <binary> --compile <args...> --link <args...>" >&2
  exit 2
fi

clangxx="$1"
llvm_profdata="$2"
profdata="$3"
binary="$4"
shift 4

if [[ "$1" != "--compile" ]]; then
  echo "missing --compile marker" >&2
  exit 2
fi
shift

compile_args=()
while [[ $# -gt 0 && "$1" != "--link" ]]; do
  compile_args+=("$1")
  shift
done

if [[ $# -eq 0 || "$1" != "--link" ]]; then
  echo "missing --link marker" >&2
  exit 2
fi
shift

link_args=("$@")
profile_dir="$(mktemp -d "${TMPDIR:-/tmp}/llvm-fdo-profile.XXXXXX")"
merged_profdata="${profile_dir}/merged.profdata"
export LLVM_PROFILE_FILE="${profile_dir}/%m-%p.profraw"

mkdir -p "$(dirname "${profdata}")" "$(dirname "${binary}")"

"${clangxx}" "${compile_args[@]}"
"${clangxx}" "${link_args[@]}"
"${binary}" >/dev/null

shopt -s nullglob
profiles=("${profile_dir}"/*.profraw)
if [[ ${#profiles[@]} -eq 0 ]]; then
  echo "instrumented LLVM did not emit any .profraw files" >&2
  exit 1
fi

"${llvm_profdata}" merge "${profiles[@]}" >"${merged_profdata}"
cp "${merged_profdata}" "${profdata}"
test -s "${profdata}"
