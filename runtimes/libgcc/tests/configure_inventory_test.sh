#!/usr/bin/env bash
# Checks that every result libgcc's configure can write has a status: each
# macro in libgcc/config.in, which configure writes into auto-target.h, and
# each @VAR@ substitution in libgcc/Makefile.in. A GCC version that adds one
# fails this test until the port classifies it. Each status is checked too:
# against the configure headers rendered for $CPU, or, for a modeled
# substitution, against the port file that carries it.
set -euo pipefail

# sh_test starts in the runfiles workspace; rootpath values are relative to it.
sources="${GCC_SOURCES}"
auto_target_h=
cflags_h=
for header in ${HEADERS}; do
  case "${header}" in
    */auto-target.h) auto_target_h="${header}" ;;
    */libgcc_configure_cflags.h) cflags_h="${header}" ;;
  esac
done
if [[ -z "${auto_target_h}" || -z "${cflags_h}" ]]; then
  echo "missing configure headers in: ${HEADERS}" >&2
  exit 1
fi

errors="${TEST_TMPDIR}/errors.txt"
: > "${errors}"
error() {
  echo "$*" >> "${errors}"
}

# Prints the lines of a status file without comments and blank lines.
statuses() {
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"
}

# Compares the names a GCC file lists with the names a status file has.
check_coverage() {
  local kind="$1" gcc_names="$2" status_names="$3"
  local name unique="${status_names}.unique"
  LC_ALL=C sort -u "${status_names}" > "${unique}"
  for name in $(LC_ALL=C comm -23 "${gcc_names}" "${unique}"); do
    error "${kind} ${name} has no status"
  done
  for name in $(LC_ALL=C comm -13 "${gcc_names}" "${unique}"); do
    error "${kind} ${name} has a status but is not in GCC's file"
  done
  for name in $(LC_ALL=C sort "${status_names}" | uniq -d); do
    error "${kind} ${name} has more than one status"
  done
}

# Whether a header defines a macro or lists it as undefined.
in_header() {
  grep -Eq "^#define $1( |\$)|^/\\* #undef $1 \\*/\$" "$2"
}

# The macros of libgcc/config.in.
config_in_names="${TEST_TMPDIR}/config_in.txt"
sed -n -e 's/^#undef \([A-Za-z0-9_]*\).*/\1/p' -e 's/^# *define \([A-Za-z0-9_]*\).*/\1/p' \
  "${sources}/libgcc/config.in" | LC_ALL=C sort -u > "${config_in_names}"
define_names="${TEST_TMPDIR}/define_status.txt"
statuses "${DEFINE_STATUS}" | awk '{ print $1 }' | LC_ALL=C sort > "${define_names}"
check_coverage macro "${config_in_names}" "${define_names}"

while read -r name status cpus; do
  applies=yes
  if [[ -n "${cpus}" && ",${cpus}," != *",${CPU},"* ]]; then
    applies=no
  fi
  in_auto_target=no
  in_cflags=no
  if in_header "${name}" "${auto_target_h}"; then
    in_auto_target=yes
  fi
  if in_header "${name}" "${cflags_h}"; then
    in_cflags=yes
  fi
  case "${status}" in
    probe-modeled | policy-modeled)
      want_auto_target="${applies}"
      want_cflags=no
      ;;
    cflags-probe-modeled)
      want_auto_target=no
      want_cflags="${applies}"
      ;;
    not-needed)
      want_auto_target=no
      want_cflags=no
      ;;
    *)
      error "macro ${name} has an unknown status: ${status}"
      continue
      ;;
  esac
  if [[ "${in_auto_target}" != "${want_auto_target}" ]]; then
    error "macro ${name} (${status}${cpus:+ on ${cpus}}): in auto-target.h for ${CPU}: ${in_auto_target}, expected ${want_auto_target}"
  fi
  if [[ "${in_cflags}" != "${want_cflags}" ]]; then
    error "macro ${name} (${status}${cpus:+ on ${cpus}}): in libgcc_configure_cflags.h for ${CPU}: ${in_cflags}, expected ${want_cflags}"
  fi
done < <(statuses "${DEFINE_STATUS}")

# The headers may hold only config.in's macros and their include guards.
for header in "${auto_target_h}" "${cflags_h}"; do
  guard="$(sed -n 's/^#ifndef \([A-Za-z0-9_]*\)$/\1/p' "${header}" | head -n 1)"
  for name in $(sed -n -e 's/^#define \([A-Za-z0-9_]*\).*/\1/p' -e 's/^\/\* #undef \([A-Za-z0-9_]*\) \*\/$/\1/p' "${header}"); do
    if [[ "${name}" != "${guard}" ]] && ! grep -qx "${name}" "${config_in_names}"; then
      error "$(basename "${header}") has ${name}, which is not in libgcc/config.in"
    fi
  done
done

# The substitutions of libgcc/Makefile.in.
makefile_names="${TEST_TMPDIR}/makefile_in.txt"
grep -o '@[A-Za-z_][A-Za-z0-9_]*@' "${sources}/libgcc/Makefile.in" | tr -d '@' \
  | LC_ALL=C sort -u > "${makefile_names}"
subst_names="${TEST_TMPDIR}/subst_status.txt"
statuses "${SUBST_STATUS}" | awk '{ print $1 }' | LC_ALL=C sort > "${subst_names}"
check_coverage substitution "${makefile_names}" "${subst_names}"

while read -r name status file; do
  case "${status}" in
    modeled)
      if [[ -z "${file}" ]]; then
        error "substitution ${name} is modeled but names no port file"
      elif [[ ! -f "${file}" ]]; then
        error "substitution ${name} names ${file}, which is not in the test's data"
      elif ! grep -Fqw "${name}" "${file}"; then
        error "substitution ${name} is modeled in ${file}, which does not mention it"
      fi
      ;;
    toolchain | not-needed | unsupported-feature | unsupported-target)
      if [[ -n "${file}" ]]; then
        error "substitution ${name} (${status}) names a port file"
      fi
      ;;
    *)
      error "substitution ${name} has an unknown status: ${status}"
      ;;
  esac
done < <(statuses "${SUBST_STATUS}")

if [[ -s "${errors}" ]]; then
  echo "libgcc's configure inventory differs from the port for ${CPU}:" >&2
  cat "${errors}" >&2
  exit 1
fi
