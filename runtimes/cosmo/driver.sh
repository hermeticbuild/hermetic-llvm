#!/bin/sh
set -eu

# Clang calls this script as its linker. Invoke the matching released GNU BFD
# through the APE loader so the action works without binfmt_misc.
if [ "${COSMO_INVOKE_BFD:-}" ]; then
    exec "$COSMO_APE_LOADER" "$COSMO_BFD" "$@"
fi

if [ "${COSMO_BFD:-}" ]; then
    COSMO_INVOKE_BFD=1 "$COSMO_CLANG" "--ld-path=$0" "$@" ${COSMO_LIBCXX:+-lcxx} -lcosmo
else
    # Search the current Clang resource headers before the SDK's libc headers.
    "$COSMO_CLANG" -nostdinc -isystem "$COSMO_RESOURCE_INCLUDE" "$@"
fi

if [ "${COSMO_FIXUP_OUTPUT:-}" ]; then
    exec "$COSMO_APE_LOADER" "$COSMO_FIXUPOBJ" "$COSMO_FIXUP_OUTPUT"
fi
