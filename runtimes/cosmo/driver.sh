#!/bin/sh
set -eu

# Clang calls this script as its linker. Invoke the matching released GNU BFD
# through the APE loader so the action works without binfmt_misc.
if [ "${COSMO_INVOKE_BFD:-}" ]; then
    exec "$COSMO_APE_LOADER" "$COSMO_BFD" "$@"
fi

if [ "${COSMO_LINK_OUTPUT:-}" ]; then
    COSMO_INVOKE_BFD=1 "$COSMO_CLANG" "--ld-path=$0" "$@" ${COSMO_LIBCXX:+-lcxx} -lcosmo
    exec "$COSMO_APE_LOADER" "$COSMO_FIXUPOBJ" "$COSMO_LINK_OUTPUT"
fi

# The SDK's intrinsics headers target an older Clang. Search the current
# compiler's resource headers first and keep the SDK's libc headers available
# to Clang's include_next directives.
"$COSMO_CLANG" -nostdinc -isystem "$COSMO_RESOURCE_INCLUDE" "$@"
if [ "${COSMO_OBJECT_OUTPUT:-}" ]; then
    exec "$COSMO_APE_LOADER" "$COSMO_FIXUPOBJ" "$COSMO_OBJECT_OUTPUT"
fi
