#!/usr/bin/env bash
set -euo pipefail

# Checks a shared (DSO) compiler-rt sanitizer runtime: it is an ELF shared
# object, leaves no personality/unwind symbols undefined, does not reference
# LLVMSupport/zlib/zstd, and exports the sanitizer interface.
#
# Env (set by the BUILD target):
#   DSO          - rlocationpath of the shared runtime (libclang_rt.{asan,tsan}.so)
#   NM           - rlocationpath of llvm-nm
#   READELF      - rlocationpath of llvm-readelf
#   IFACE_PREFIX - exported interface symbol prefix to require (e.g. __asan_)

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^.*/$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

dso="$(rlocation "${DSO}")"
nm="$(rlocation "${NM}")"
readelf="$(rlocation "${READELF}")"

"${readelf}" -h "${dso}" | grep -qE "Type:[[:space:]]+DYN" \
  || { echo "${dso} is not a shared object (DYN)"; "${readelf}" -h "${dso}"; exit 1; }

undef="${TEST_TMPDIR:-/tmp}/undef.txt"
"${nm}" -D --undefined-only "${dso}" > "${undef}" 2>/dev/null || true

fail=0
for sym in __gxx_personality_v0 __gcc_personality_v0 _Unwind_Resume _Unwind_RaiseException; do
  if grep -qw "${sym}" "${undef}"; then
    echo "Unexpected undefined symbol (closure should satisfy it): ${sym}"
    fail=1
  fi
done

if grep -qiE "llvm::symbolize|_ZN4llvm|zlibVersion|ZSTD_" "${undef}"; then
  echo "DSO references LLVMSupport/zlib/zstd (internal symbolizer not dropped):"
  grep -iE "llvm::symbolize|_ZN4llvm|zlibVersion|ZSTD_" "${undef}" | head
  fail=1
fi

# The instrumented app resolves the interface (e.g. __asan_report_*) from the DSO.
iface_count="$("${nm}" -D --defined-only "${dso}" | grep -cE "[[:xdigit:]]+ [TWtw] ${IFACE_PREFIX}")"
if [[ "${iface_count}" -lt 10 ]]; then
  echo "DSO exports too few ${IFACE_PREFIX} interface symbols (${iface_count})"
  "${nm}" -D --defined-only "${dso}" | grep -iE "asan|tsan|__interceptor|__sanitizer" | head -40
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "---- undefined symbols ----"
  cat "${undef}"
  exit 1
fi
