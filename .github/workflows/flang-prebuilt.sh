#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

LLVM_VERSION=$(python3 - <<'PY'
import re
from pathlib import Path

match = re.search(r'^LLVM_VERSION\s*=\s*"([^"]+)"', Path("MODULE.bazel").read_text(), re.M)
if not match:
    raise SystemExit("Could not find LLVM_VERSION in MODULE.bazel")
print(match.group(1))
PY
)

RELEASE_TAG="${FLANG_RELEASE_TAG:?Set FLANG_RELEASE_TAG to flang-<LLVM version>-r<revision>}"
revision="${RELEASE_TAG#flang-${LLVM_VERSION}-}"
if [[ "${RELEASE_TAG}" != "flang-${LLVM_VERSION}-${revision}" || ! "${revision}" =~ ^r[1-9][0-9]*$ ]]; then
  echo "Release tag '${RELEASE_TAG}' must match flang-${LLVM_VERSION}-r<positive revision>" >&2
  exit 1
fi

archive="bazel-out/linux_amd64_musl-opt/bin/prebuilt/flang/linux_amd64_musl_release.tar.zst"
release_dir="${FLANG_RELEASE_DIR:-release}"
release_asset="flang-toolchain-${LLVM_VERSION}-linux-amd64-musl.tar.zst"
destination="${release_dir}/${release_asset}"
bazel_startup_args=()
if [[ -n "${FLANG_BAZEL_OUTPUT_BASE:-}" ]]; then
  bazel_startup_args+=("--output_base=${FLANG_BAZEL_OUTPUT_BASE}")
fi

if [[ -e "${destination}" || -e "${release_dir}/SHA256.txt" ]]; then
  echo "Release staging files already exist in '${release_dir}'" >&2
  exit 1
fi

bazel \
  "${bazel_startup_args[@]}" \
  --bazelrc=".github/workflows/ci.bazelrc" \
  test \
  --config=release \
  --platforms=//platforms:linux_amd64_musl \
  --nocache_test_results \
  --test_output=errors \
  //prebuilt/flang:linux_amd64_musl_smoke

bazel \
  "${bazel_startup_args[@]}" \
  --bazelrc=".github/workflows/ci.bazelrc" \
  build \
  --config=release \
  --platforms=//platforms:linux_amd64_musl \
  --remote_download_outputs=toplevel \
  //prebuilt/flang:linux_amd64_musl_release

if [[ ! -f "${archive}" ]]; then
  echo "Expected archive not found at '${archive}'" >&2
  exit 1
fi

e2e/rules_fortran/verify.sh "${archive}"

mkdir -p "${release_dir}"
cp "${archive}" "${destination}"
(cd "${release_dir}" && shasum -a 256 "${release_asset}" > SHA256.txt)

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=${LLVM_VERSION}" >> "${GITHUB_OUTPUT}"
  echo "tag=${RELEASE_TAG}" >> "${GITHUB_OUTPUT}"
fi
