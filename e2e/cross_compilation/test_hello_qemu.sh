#!/usr/bin/env bash
set -euo pipefail

resolve_runfile() {
    local path="$1"

    if [[ "${path}" = /* && -e "${path}" ]]; then
        printf '%s\n' "${path}"
        return
    fi

    if [[ -n "${RUNFILES_DIR:-}" ]]; then
        if [[ -e "${RUNFILES_DIR}/${path}" ]]; then
            printf '%s\n' "${RUNFILES_DIR}/${path}"
            return
        fi
        if [[ -e "${RUNFILES_DIR}/_main/${path}" ]]; then
            printf '%s\n' "${RUNFILES_DIR}/_main/${path}"
            return
        fi
    fi

    if [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]]; then
        local resolved
        resolved="$(grep -sm1 "^${path} " "${RUNFILES_MANIFEST_FILE}" | cut -f2- -d' ' || true)"
        if [[ -n "${resolved}" ]]; then
            printf '%s\n' "${resolved}"
            return
        fi
        resolved="$(grep -sm1 "^_main/${path} " "${RUNFILES_MANIFEST_FILE}" | cut -f2- -d' ' || true)"
        if [[ -n "${resolved}" ]]; then
            printf '%s\n' "${resolved}"
            return
        fi
    fi

    echo "Could not resolve runfile: ${path}" >&2
    exit 1
}

HELLO_WORLD="$(resolve_runfile "${BINARY}")"

OUTPUT="$("${HELLO_WORLD}")"

if [[ "${OUTPUT}" != "${EXPECTED_OUTPUT}" ]]; then
    echo "Expected \"${EXPECTED_OUTPUT}\", got: ${OUTPUT}" >&2
    exit 1
fi
