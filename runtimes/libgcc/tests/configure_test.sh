#!/usr/bin/env bash
# Runs gcc/config.gcc and libgcc/config.host for $TARGET as GCC's configure
# scripts do, and compares what they select with $EXPECTED, the configuration
# that //3rd_party/gcc/libgcc ports. It also compares the configure results that
# Makefile.in's conditionals read. $CHECKS holds the results that the two
# scripts and those conditionals read, some probed with the target's toolchain
# and the rest fixed by policy.
set -euo pipefail

# sh_test starts in the runfiles workspace; rootpath values are relative to it.
sources="${PWD}/${GCC_SOURCES}"
checks="${CHECKS}"

is_defined() {
  grep -q "^#define $1 " "${checks}"
}

host_address=32
if is_defined LIBGCC_HOST_ADDRESS_64; then
  host_address=64
fi
libgcc_cv_cfi=no
if is_defined LIBGCC_CV_CFI; then
  libgcc_cv_cfi=yes
fi
enable_initfini_array=no
if is_defined GCC_ENABLE_INITFINI_ARRAY; then
  enable_initfini_array=yes
fi
target_thread_file="$(sed -n 's/^#define LIBGCC_TARGET_THREAD_FILE "\(.*\)"$/\1/p' "${checks}")"

# Prints yes when a check succeeded and no otherwise, as configure's cache
# variables hold them.
yes_no() {
  if is_defined "$1"; then
    echo yes
  else
    echo no
  fi
}

# Prints a variable's words separated by single spaces.
words() {
  # shellcheck disable=SC2048,SC2086
  echo $*
}

actual="${TEST_TMPDIR}/actual.txt"
{
  # libgcc/configure.ac sources config.host, then defaults sfp_machine_header,
  # drops tmake fragments that do not exist, and maps the thread model to a
  # header (GCC_AC_THREAD_HEADER). The scripts read and set many variables,
  # so each runs in a subshell without -e and -u.
  (
    set +eu
    host="${TARGET}"
    srcdir="${sources}/libgcc"
    . "${srcdir}/config.host" > /dev/null
    if test -z "${sfp_machine_header}"; then
      sfp_machine_header="${cpu_type}/sfp-machine.h"
      if ! test -f "${srcdir}/config/${sfp_machine_header}"; then
        sfp_machine_header=no-sfp-machine.h
      fi
    fi
    tmake_file_=
    for f in ${tmake_file}; do
      if test -f "${srcdir}/config/${f}"; then
        tmake_file_="${tmake_file_} ${f}"
      fi
    done
    echo "enable_execute_stack=${enable_execute_stack}"
    echo "libgcc_tm_file=$(words ${tm_file})"
    echo "md_unwind_def_header=${md_unwind_def_header}"
    echo "md_unwind_header=${md_unwind_header}"
    echo "sfp_machine_header=${sfp_machine_header}"
    echo "thread_header=gthr-${target_thread_file}.h"
    echo "tmake_file=$(words ${tmake_file_})"
    echo "unwind_header=${unwind_header}"
  )
  # gcc/configure.ac sources config.gcc, then appends initfini-array.h to
  # tm_file. Its other tm_file and tm_defines additions come from options this
  # port leaves at their defaults.
  (
    set +eu
    build="${TARGET}"
    host="${TARGET}"
    target="${TARGET}"
    srcdir="${sources}/gcc"
    # config.gcc preprocesses aarch64-option-extensions.def with configure's
    # CPP to parse --with-arch and the like. With none of them set, it does
    # not use the output.
    ac_cv_prog_CPP=true
    . "${srcdir}/config.gcc" > /dev/null
    if test "${enable_initfini_array}" != no; then
      tm_file="${tm_file} initfini-array.h"
    fi
    echo "tm_defines=$(words ${tm_defines})"
    echo "tm_file=$(words ${tm_file})"
  )
  # libgcc/configure.ac substitutes these into Makefile.in, whose
  # conditionals add decimal floating-point, fixed-point and, from GCC 14,
  # strub objects.
  echo "decimal_float=$(yes_no LIBGCC_CV_DFP)"
  echo "fixed_point=$(yes_no LIBGCC_CV_FIXED_POINT)"
  if grep -q '@HAVE_STRUB_SUPPORT@' "${sources}/libgcc/Makefile.in"; then
    echo "have_strub_support=$(yes_no LIBGCC_CV_STRUB_SUPPORT)"
  fi
} | LC_ALL=C sort > "${actual}"

if ! diff -u "${EXPECTED}" "${actual}"; then
  echo "config.gcc and config.host select a different configuration than the port" >&2
  exit 1
fi
