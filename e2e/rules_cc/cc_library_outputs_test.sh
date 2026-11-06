#!/usr/bin/env bash
set -euo pipefail

archive=no
shared=no
interface=no
for output in ${LIBRARY_OUTPUTS}; do
    [[ -f "${output}" ]] || { echo "missing cc_library output: ${output}" >&2; exit 1; }
    case "${output}" in
        *.dll.a | *.if.lib | *.ifso | *.tbd) interface=yes ;;
        *.a | *.lib) archive=yes ;;
        *.so | *.dylib | *.dll) shared=yes ;;
    esac
done

if [[ "${archive}" != yes || "${shared}" != "${EXPECT_SHARED}" ]]; then
    echo "expected archive=yes and shared=${EXPECT_SHARED}; got: ${LIBRARY_OUTPUTS}" >&2
    exit 1
fi
if [[ "${EXPECT_SHARED}" == no && "${interface}" == yes ]]; then
    echo "unexpected interface library: ${LIBRARY_OUTPUTS}" >&2
    exit 1
fi
