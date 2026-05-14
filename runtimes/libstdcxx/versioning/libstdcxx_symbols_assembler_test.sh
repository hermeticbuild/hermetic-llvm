#!/usr/bin/env bash

set -euo pipefail

assembler="${ASSEMBLER:?}"

"${assembler}" \
  "${TEST_TMPDIR}/insert.actual" \
  "${BASE:?}" \
  "${PORT_INSERT:?}"
diff -u "${INSERT_GOLDEN:?}" "${TEST_TMPDIR}/insert.actual"

"${assembler}" \
  "${TEST_TMPDIR}/append.actual" \
  "${BASE:?}" \
  "${PORT_APPEND:?}"
diff -u "${APPEND_GOLDEN:?}" "${TEST_TMPDIR}/append.actual"
