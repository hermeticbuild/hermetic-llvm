#!/usr/bin/env bash
set -euo pipefail

generator="$PWD/$1"
clang="$PWD/$2"
cd "$TEST_TMPDIR"

# A named module with modular and textual headers, like the libc++ module.
printf '#pragma once\n#include "textual.h"\ninline int used() { return TEXTUAL_VALUE; }\n' > used.h
printf '#define TEXTUAL_VALUE 42\n' > textual.h
printf 'header used.h\ntextual textual.h\n' > headers.params
"$generator" --module=lib --use=dep lib.modulemap @headers.params
for expected in 'header "used.h" { size 78 }' 'textual header "textual.h" { size 25 }' 'use "dep"'; do
  if ! grep -qF "$expected" lib.modulemap; then
    echo "Expected '$expected' in:" >&2
    cat lib.modulemap >&2
    exit 1
  fi
done
printf 'module dep {}\n' > dep.modulemap

modules_flags=(-x c++ -fmodules -fno-implicit-modules -fno-implicit-module-maps)
"$clang" "${modules_flags[@]}" -Xclang -fmodules-local-submodule-visibility \
  -fmodules-strict-decluse -fmodule-name=lib -fmodule-map-file=dep.modulemap \
  -fmodule-map-file=lib.modulemap -Xclang -emit-module -c lib.modulemap -o lib.pcm

printf '#include "used.h"\nint main() { return used() == 42 ? 0 : 1; }\n' > main.cc
"$clang" "${modules_flags[@]}" -fsyntax-only -fmodule-map-file=dep.modulemap \
  -fmodule-map-file=lib.modulemap -fmodule-file=lib.pcm -I. main.cc

# Parsing the module map must not resolve the headers of unused submodules.
printf 'int unrelated;\n' > unrelated.cc
status_calls() {
  local stats
  if ! stats=$("$clang" "${modules_flags[@]}" -fsyntax-only \
      -fmodule-map-file=dep.modulemap -fmodule-map-file=lib.modulemap \
      -Xclang -print-stats unrelated.cc 2>&1); then
    echo "$stats" >&2
    return 1
  fi
  if [[ "$stats" =~ ([0-9]+)\ status\(\)\ calls ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "$stats" >&2
    return 1
  fi
}

before=$(status_calls)
for i in {1..64}; do
  printf '%1000s\n' '' > "unused$i.h"
  printf 'header unused%s.h\n' "$i" >> headers.params
done
"$generator" --module=lib --use=dep lib.modulemap @headers.params
after=$(status_calls)
if [[ "$before" != "$after" ]]; then
  echo "Unused headers increased status() calls from $before to $after" >&2
  exit 1
fi
