#!/bin/bash
# The reference build gen_manifest.py transcribes: glibc's own `configure &&
# make V=1`, with this toolchain's Clang, in a throwaway container.
#
#   reference_build.sh <x86_64|aarch64> <toolchain-dir> <work-dir>
#
# <toolchain-dir> is the prebuilt LLVM this module downloads, as it lies in a
# Bazel output base; it is mounted read-only, not copied (its bin/ is relative
# symlinks to one multi-call binary, which `cp -L` turns into 7 GB):
#   $(bazel info output_base)/external/llvm++llvm_toolchain_minimal+llvm-toolchain-minimal-linux-amd64
# <work-dir> must hold glibc-2.44/, the release tarball unpacked
# (GLIBC_STATIC_VERSION in BUILD.bazel), and receives build-<arch>/ with
# make.log.  Then:
#
#   AR=<toolchain-dir>/bin/llvm-ar ./gen_manifest.py <arch> <work-dir>/glibc-2.44 \
#       <work-dir>/build-<arch> <work-dir>/build-<arch>/make.log <arch>
#
# The container's own glibc and gcc are there for two things only: configure's
# link tests need *a* libc to link against, and make builds a few host tools
# (BUILD_CC).  Nothing of theirs reaches the manifest or gen/ -- every compile
# the manifest keeps is of glibc's sources with glibc's flags, and the Bazel
# rule replays it against the toolchain's hermetic headers.
#
# CFLAGS=-O2 replaces glibc's default "-g -O2".  The manifest drops -g anyway,
# but two of the generated files are compiler *output* (errlist-data-aux.S,
# siglist-aux.S), and with -g they carry DWARF that names the directories this
# build ran in -- which would make gen/ depend on where it was generated.
#
# The work dir is mounted at /w, which is the path gen_manifest.py expects to
# find in the log (LOG_BUILD / LOG_SRC override it).
set -euo pipefail
arch="$1"
toolchain="$(realpath "$2")"
work="$(realpath "$3")"

case "$arch" in
  x86_64)  cross_pkgs=""; target="" ;;
  aarch64) cross_pkgs="gcc-aarch64-linux-gnu libc6-dev-arm64-cross linux-libc-dev-arm64-cross"
           target=" -target aarch64-linux-gnu" ;;
  *) echo "unsupported architecture: $arch" >&2; exit 2 ;;
esac

docker run --rm -u 0 -v "$work":/w -v "$toolchain":/tc:ro ubuntu:24.04 bash -euxc "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends make gawk bison python3 gcc libc6-dev \
      linux-libc-dev binutils sed grep texinfo gettext $cross_pkgs >/dev/null
  export PATH=/tc/bin:\$PATH
  mkdir -p /w/build-$arch && cd /w/build-$arch
  /w/glibc-2.44/configure --prefix=/usr --host=$arch-linux-gnu --build=x86_64-linux-gnu \
      CC='clang$target' CXX='clang++$target' BUILD_CC=gcc CFLAGS=-O2 \
      LD=ld.lld AR=llvm-ar NM=llvm-nm OBJDUMP=llvm-objdump OBJCOPY=llvm-objcopy READELF=llvm-readelf \
      --with-lld --disable-werror --enable-kernel=4.19 --disable-nscd \
      --disable-timezone-tools --without-selinux > configure.log 2>&1
  make -j\$(nproc) V=1 > make.log 2>&1
  ls -la libc.a math/libm.a
"
