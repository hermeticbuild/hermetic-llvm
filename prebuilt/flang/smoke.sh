#!/bin/sh
set -eu

archive="$1"
source="$2"
bsdtar="$3"
unpacked="$TEST_TMPDIR/first location"
relocated="$TEST_TMPDIR/relocated location"
mkdir -p "$unpacked"
"$bsdtar" -xf "$archive" -C "$unpacked"
mv "$unpacked" "$relocated"

flang="$relocated/bin/flang"
"$flang" --version > "$TEST_TMPDIR/version.txt"

env -i HOME="$TEST_TMPDIR" PATH=/no-host-tools "$flang" -### "$source" -o "$TEST_TMPDIR/smoke" > "$TEST_TMPDIR/driver.txt" 2>&1
grep -F "$relocated/bin/ld.lld" "$TEST_TMPDIR/driver.txt"
if grep -E '/usr/bin/(ld|gcc|g\+\+)|/usr/lib/gcc' "$TEST_TMPDIR/driver.txt"; then
  echo 'driver selected a host linker or GCC installation' >&2
  exit 1
fi

env -i HOME="$TEST_TMPDIR" PATH=/no-host-tools "$flang" "$source" -o "$TEST_TMPDIR/smoke"
"$TEST_TMPDIR/smoke" > "$TEST_TMPDIR/output.txt"
grep -Fx 'Fortran=25' "$TEST_TMPDIR/output.txt"

"$relocated/bin/llvm-readelf" -l -d "$TEST_TMPDIR/smoke" > "$TEST_TMPDIR/elf.txt"
if grep -E 'INTERP|NEEDED' "$TEST_TMPDIR/elf.txt"; then
  echo 'output has an ELF interpreter or dynamic dependency' >&2
  exit 1
fi

module="$relocated/lib/clang/23/finclude/flang/x86_64-unknown-linux-musl/iso_c_binding.mod"
mv "$module" "$module.hidden"
if env -i HOME="$TEST_TMPDIR" PATH=/no-host-tools "$flang" -c "$source" -o "$TEST_TMPDIR/no-module.o" > "$TEST_TMPDIR/no-module.txt" 2>&1; then
  echo 'missing intrinsic module was silently supplied elsewhere' >&2
  exit 1
fi
mv "$module.hidden" "$module"

mv "$relocated/bin/ld.lld" "$relocated/bin/ld.lld.hidden"
if env -i HOME="$TEST_TMPDIR" PATH=/no-host-tools "$flang" "$source" -o "$TEST_TMPDIR/no-linker" > "$TEST_TMPDIR/no-linker.txt" 2>&1; then
  echo 'missing packaged linker was silently replaced' >&2
  exit 1
fi
mv "$relocated/bin/ld.lld.hidden" "$relocated/bin/ld.lld"

runtime="$relocated/lib/clang/23/lib/x86_64-unknown-linux-musl/libflang_rt.runtime.a"
mv "$runtime" "$runtime.hidden"
if env -i HOME="$TEST_TMPDIR" PATH=/no-host-tools "$flang" "$source" -o "$TEST_TMPDIR/no-runtime" > "$TEST_TMPDIR/no-runtime.txt" 2>&1; then
  echo 'missing packaged Flang runtime was silently replaced' >&2
  exit 1
fi
