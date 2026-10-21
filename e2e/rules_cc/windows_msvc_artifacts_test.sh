#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }
f=
set -e
# --- end runfiles.bash initialization v3 ---

set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

resolve() {
  local key="${1//\\//}"
  local path
  path="$(rlocation "${key}")"
  [[ -e "${path}" ]] || fail "missing runfile: ${key}"
  printf '%s\n' "${path}"
}

LLVM_AR="$(resolve "${LLVM_AR}")"
LLVM_NM="$(resolve "${LLVM_NM}")"
LLVM_READOBJ="$(resolve "${LLVM_READOBJ}")"

found_md=0
found_mt=0
found_thinlto=0
found_dll_consumer=0
found_import_library=0
found_pdb=0
debug_executable=
debug_pdb=

machine_line_matches() {
  local machine="$1"
  grep -Eq "Machine: IMAGE_FILE_MACHINE_${machine}([[:space:]]|$)"
}

assert_machine() {
  local artifact="$1"
  "${LLVM_READOBJ}" --file-headers "${artifact}" |
    machine_line_matches "${MACHINE}" ||
    fail "wrong or missing ${MACHINE} machine in ${artifact}"
}

archive_members_match_machine() {
  local machine="$1"
  local member_count="$2"
  local native_format
  local import_format
  case "${machine}" in
    AMD64)
      native_format=COFF-x86-64
      import_format=COFF-import-file-x86-64
      ;;
    ARM64)
      native_format=COFF-ARM64
      import_format=COFF-import-file-ARM64
      ;;
    *) return 1 ;;
  esac
  awk \
    -v expected_machine="IMAGE_FILE_MACHINE_${machine}" \
    -v expected_members="${member_count}" \
    -v import_format="${import_format}" \
    -v native_format="${native_format}" '
      function finish_member() {
        if (!in_member) return
        members++
        if (format == native_format) {
          if (machine != expected_machine) invalid = 1
        } else if (format == import_format) {
          if (machine != "" && machine != expected_machine) invalid = 1
        } else {
          invalid = 1
        }
      }
      /^File: / {
        finish_member()
        in_member = 1
        format = ""
        machine = ""
        next
      }
      /^Format: / { format = $2; next }
      /^[[:space:]]*Machine: IMAGE_FILE_MACHINE_/ { machine = $2; next }
      END {
        finish_member()
        if (invalid || members != expected_members || members == 0) exit 1
      }
    '
}

if printf '%s\n' 'Machine: IMAGE_FILE_MACHINE_ARM64EC (0xA641)' |
  machine_line_matches ARM64; then
  fail "ARM64 machine matcher also accepts ARM64EC"
fi

if printf '%s\n' \
  'File: mixed.lib(amd64.obj)' \
  'Format: COFF-x86-64' \
  '  Machine: IMAGE_FILE_MACHINE_AMD64 (0x8664)' \
  'File: mixed.lib(arm64.obj)' \
  'Format: COFF-ARM64' \
  '  Machine: IMAGE_FILE_MACHINE_ARM64 (0xAA64)' |
  archive_members_match_machine AMD64 2; then
  fail "archive machine matcher accepts a mixed-machine archive"
fi

if printf '%s\n' \
  'File: arm64ec.lib(member.obj)' \
  'Format: COFF-ARM64' \
  '  Machine: IMAGE_FILE_MACHINE_ARM64EC (0xA641)' |
  archive_members_match_machine ARM64 1; then
  fail "archive machine matcher accepts an ARM64EC member as ARM64"
fi

printf '%s\n' \
  'File: valid.lib(member.obj)' \
  'Format: COFF-x86-64' \
  '  Machine: IMAGE_FILE_MACHINE_AMD64 (0x8664)' \
  'File: valid.lib(import)' \
  'Format: COFF-import-file-x86-64' |
  archive_members_match_machine AMD64 2 ||
  fail "archive machine matcher rejects valid AMD64 members"

for artifact_key in ${ARTIFACTS}; do
  artifact="$(resolve "${artifact_key}")"
  basename="$(basename "${artifact}")"

  [[ -s "${artifact}" ]] || fail "missing or empty artifact: ${artifact}"

  case "${basename}" in
    c++.dll|libc++.dll)
      fail "dynamic libc++ artifact exposed: ${artifact}"
      ;;
    *.exe|*.dll)
      assert_machine "${artifact}"
      ;;
    *.lib)
      members="$("${LLVM_AR}" t "${artifact}")"
      [[ -n "${members}" ]] ||
        fail "empty COFF archive or import library: ${artifact}"
      member_count="$(awk 'NF { count++ } END { print count + 0 }' <<<"${members}")"
      "${LLVM_READOBJ}" --file-headers "${artifact}" |
        archive_members_match_machine "${MACHINE}" "${member_count}" ||
        fail "wrong, mixed, or uninspected ${MACHINE} member in ${artifact}"
      ;;
    *.pdb)
      grep -a -Fq "Microsoft C/C++ MSF 7.00" "${artifact}" ||
        fail "invalid PDB signature: ${artifact}"
      found_pdb=1
      debug_pdb="${artifact}"
      ;;
  esac

  case "${basename}" in
    windows_msvc_libcxx_behavior_md.exe)
      imports="$("${LLVM_READOBJ}" --coff-imports "${artifact}")"
      grep -Fq "Name: VCRUNTIME140.dll" <<<"${imports}" ||
        fail "/MD behavior binary does not import VCRuntime"
      grep -Fq "Name: api-ms-win-crt-" <<<"${imports}" ||
        fail "/MD behavior binary does not import UCRT"
      found_md=1
      ;;
    windows_msvc_libcxx_behavior_mt.exe)
      imports="$("${LLVM_READOBJ}" --coff-imports "${artifact}")"
      if grep -Eq "Name: (MSVCP140|VCRUNTIME140|api-ms-win-crt-)" <<<"${imports}"; then
        fail "/MT behavior binary imports a dynamic Microsoft runtime"
      fi
      found_mt=1
      ;;
    windows_msvc_libcxx_behavior_thinlto.exe)
      found_thinlto=1
      ;;
    windows_msvc_libcxx_behavior_debug.exe)
      debug_executable="${artifact}"
      ;;
    windows_msvc_dll_behavior.exe)
      found_dll_consumer=1
      ;;
    windows_add.dll)
      "${LLVM_READOBJ}" --coff-exports "${artifact}" |
        grep -Fq "Name: add42" ||
        fail "dllexport DLL is missing add42"
      ;;
    windows_explicit_def.dll)
      "${LLVM_READOBJ}" --coff-exports "${artifact}" |
        grep -Fq "Name: explicit_add42" ||
        fail "explicit DEF DLL is missing explicit_add42"
      ;;
    windows_msvc_generated_def.dll)
      "${LLVM_READOBJ}" --coff-exports "${artifact}" |
        grep -Fq "Name: generated_add42" ||
        fail "generated DEF DLL is missing generated_add42"
      ;;
    windows_msvc_generated_def_thinlto.dll)
      "${LLVM_READOBJ}" --coff-exports "${artifact}" |
        grep -Fq "Name: generated_add42" ||
        fail "ThinLTO generated DEF DLL is missing generated_add42"
      ;;
    *.if.lib)
      found_import_library=1
      ;;
    windows_msvc_libcxx_behavior_support.lib)
      "${LLVM_NM}" -u "${artifact}" | grep -Fq "__udivti3" ||
        fail "behavior archive does not exercise compiler-rt wide division"
      directives="$("${LLVM_READOBJ}" --coff-directives "${artifact}")"
      if grep -Fiq "defaultlib:libc++.lib" <<<"${directives}"; then
        fail "behavior archive contains a hidden libc++ auto-link directive"
      fi
      ;;
  esac
done

[[ "${found_md}" == 1 ]] || fail "missing /MD behavior executable"
[[ "${found_mt}" == 1 ]] || fail "missing /MT behavior executable"
[[ "${found_thinlto}" == 1 ]] || fail "missing ThinLTO behavior executable"
[[ "${found_dll_consumer}" == 1 ]] || fail "missing DLL consumer executable"
[[ "${found_import_library}" == 1 ]] || fail "missing declared import library"
[[ "${found_pdb}" == 1 ]] || fail "missing declared PDB"
[[ -n "${debug_executable}" ]] || fail "missing debug executable"
[[ -n "${debug_pdb}" ]] || fail "missing debug PDB"

"${LLVM_READOBJ}" --coff-debug-directory "${debug_executable}" |
  grep -Fq "PDBFileName: $(basename "${debug_pdb}")" ||
  fail "debug executable does not reference its declared PDB"
