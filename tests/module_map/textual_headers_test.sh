#!/usr/bin/env bash
set -euo pipefail

generator="$PWD/$1"
clang="$PWD/$2"
cd "$TEST_TMPDIR"

printf '#include "nested.h"\n' > system.h
printf 'typedef int system_int;\n' > nested.h
printf 'system.h\nnested.h\n' > headers.params
"$generator" crosstool.modulemap @headers.params

printf '#include "system.h"\n' > client.h
printf '#include "client.h"\nsystem_int value;\n' > main.c
cat > client.modulemap <<'EOF'
module client {
  textual header "client.h"
  use crosstool
}
module undeclared {
  textual header "undeclared.h"
}
EOF
printf 'typedef int undeclared_int;\n' > undeclared.h

compile() {
  "$clang" -fsyntax-only -fmodules -fno-implicit-modules \
    -fno-implicit-module-maps -fmodules-strict-decluse -fmodule-name=client \
    -fmodule-map-file=crosstool.modulemap -fmodule-map-file=client.modulemap \
    -I. "$@" main.c
}

status_calls() {
  local stats
  if ! stats=$(compile -Xclang -print-stats 2>&1); then
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

# Adding unused headers must not increase filesystem lookups when validating
# system.h's nested include. Use a distinct size to avoid lazy lookup matches.
before=$(status_calls)
for i in {1..64}; do
  printf '%1000s\n' '' > "unused$i.h"
  printf 'unused%s.h\n' "$i" >> headers.params
done
"$generator" crosstool.modulemap @headers.params
after=$(status_calls)
if [[ "$before" != "$after" ]]; then
  echo "Unused headers increased status() calls from $before to $after" >&2
  exit 1
fi

# The optimization must preserve layering checks on textual includes.
printf '#include "undeclared.h"\n' >> client.h
if compile > error.log 2>&1; then
  echo "Expected an error for an undeclared header dependency" >&2
  exit 1
fi
if ! grep -q "does not directly depend on a module exporting 'undeclared.h'" error.log; then
  cat error.log >&2
  exit 1
fi
