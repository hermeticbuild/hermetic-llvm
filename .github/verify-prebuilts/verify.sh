#!/usr/bin/env bash
# Rebuilds an LLVM prebuilt release from its commit (the current directory)
# with that commit's own release script and compares the archives with the
# published ones.
#
# Usage: verify.sh <release tag> <all release tags in chain order...>
#
# The build bootstraps from llvm-22.1.7-2 instead of the seed the release used.
# Stages 2 and 3 are compiled by stage 1, which is built from the release's
# sources, so they do not depend on which correct compiler built stage 1.
#
# Every action is executed except the FDO training actions, whose profile
# counters depend on memory addresses and thus differ between runs. Those reuse
# the results that the release build stored in the remote cache, which have the
# same action digests if stage 2 is identical. A profile only steers
# optimizations, so it cannot change what the rebuilt binaries do. The execution
# log is checked to ensure that no other action used a cached result.
#
# Release archives downloaded during the build must come from releases published
# before the first release in the chain or from releases earlier in the chain,
# which have already been verified.
#
# The rebuilt archives must be identical to the published ones. The only
# accepted difference is the link time that lld-link records in the COFF header
# of Windows executables when it is not told to omit it.

set -euo pipefail

tag="$1"
shift
known_archives="${VERIFY_DIR}/.github/verify-prebuilts/known-archives.tsv"
first_unverified_date="$(awk -F'\t' -v t="$1" '$2 == t {print $3; exit}' "${known_archives}")"
[[ -n "${first_unverified_date}" ]]

verified_tags=()
for t in "$@"; do
  [[ "${t}" == "${tag}" ]] && break
  verified_tags+=("${t}")
done

cat >> "${HOME}/.bazelrc" <<EOF
common --remote_header=x-buildbuddy-api-key=4jtaxdhxtyu4ylxdEwI7
common --bes_header=x-buildbuddy-api-key=4jtaxdhxtyu4ylxdEwI7
common --remote_accept_cached
common --modify_execution_info=.*=+no-remote-cache,LLVMFDOProfile(Compile|Link)=-no-remote-cache
common --noremote_upload_local_results
common --execution_log_compact_file=${RUNNER_TEMP}/exec_log.zst
EOF

# Checks that a rebuilt archive differs from the published one only in the
# COFF TimeDateStamp of Windows executables.
same_except_pe_timestamps() {
  local name="$1" dir
  dir="$(mktemp -d)"
  curl -fsSL "https://github.com/hermeticbuild/hermetic-llvm/releases/download/${tag}/${name}" -o "${dir}/published.tar.zst" || return 1
  mkdir "${dir}/published" "${dir}/rebuilt" || return 1
  zstd -dc "${dir}/published.tar.zst" | tar -xf - -C "${dir}/published" || return 1
  zstd -dc "release/${name}" | tar -xf - -C "${dir}/rebuilt" || return 1
  # Names, sizes, modes and times of all entries must match exactly.
  diff <(zstd -dc "${dir}/published.tar.zst" | tar -tvf -) <(zstd -dc "release/${name}" | tar -tvf -) || return 1
  python3 - "${dir}/published" "${dir}/rebuilt" <<'PY'
import os
import struct
import sys

published, rebuilt = sys.argv[1], sys.argv[2]


def without_coff_timestamp(data):
    if data[:2] != b"MZ" or len(data) < 0x40:
        return None
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        return None
    data = bytearray(data)
    data[pe + 8:pe + 12] = bytes(4)
    return bytes(data)


ok = True
for root, _, files in os.walk(published):
    for file in files:
        path = os.path.join(root, file)
        rel = os.path.relpath(path, published)
        other = os.path.join(rebuilt, rel)
        if os.path.islink(path) or os.path.islink(other):
            if not (os.path.islink(path) and os.path.islink(other) and os.readlink(path) == os.readlink(other)):
                print(f"{rel}: differs")
                ok = False
            continue
        with open(path, "rb") as f:
            a = f.read()
        with open(other, "rb") as f:
            b = f.read()
        if a == b:
            continue
        normalized = without_coff_timestamp(a)
        if normalized is not None and normalized == without_coff_timestamp(b):
            print(f"{rel}: differs only in the COFF TimeDateStamp")
        else:
            print(f"{rel}: differs")
            ok = False
sys.exit(0 if ok else 1)
PY
}

python3 "${VERIFY_DIR}/.github/verify-prebuilts/use_seed.py"
git diff --stat

build_log="${RUNNER_TEMP}/build.log"
GITHUB_REF_NAME="${tag}" bash .github/workflows/llvm-prebuilt.sh 2>&1 | tee "${build_log}"

failed=0
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
echo "## ${tag} ($(git rev-parse --short HEAD), bootstrapped from llvm-22.1.7-2)" >> "${summary}"

# Only FDO training actions may have taken their results from a cache.
echo "### Build" >> "${summary}"
while read -r line; do
  echo "- \`${line}\`" >> "${summary}"
done < <(grep -o -E 'INFO: [0-9]+ processes: .*' "${build_log}")
zstd -dc "${RUNNER_TEMP}/exec_log.zst" | python3 "${VERIFY_DIR}/.github/verify-prebuilts/check_exec_log.py" >> "${summary}" || failed=1

# Release archives downloaded during the build (bootstrap seeds and extras).
echo "### Downloaded release archives" >> "${summary}"
found_archive=0
for cache_dir in "${HOME}/.cache/bazel-repo/content_addressable/sha256" "${HOME}/.cache/bazel/_bazel_${USER}/cache/repos/v1/content_addressable/sha256"; do
  [[ -d "${cache_dir}" ]] || continue
  for entry in "${cache_dir}"/*; do
    digest="$(basename "${entry}")"
    while IFS=$'\t' read -r _ archive_tag published name; do
      found_archive=1
      status="published before the first release in the chain"
      if [[ ! "${published}" < "${first_unverified_date}" ]]; then
        status="not verified"
        for t in "${verified_tags[@]}"; do
          [[ "${t}" == "${archive_tag}" ]] && status="verified earlier in this chain"
        done
      fi
      echo "- ${name} (${archive_tag}): ${status}" >> "${summary}"
      if [[ "${status}" == "not verified" ]]; then
        echo "::error::The build downloaded ${name} from ${archive_tag}, which has not been verified"
        failed=1
      fi
    done < <(awk -F'\t' -v d="${digest}" '$1 == d' "${known_archives}")
  done
done
if [[ "${found_archive}" == 0 ]]; then
  echo "::error::Could not find any downloaded release archive in the repository cache"
  failed=1
fi

# The rebuilt archives must be identical to the published ones.
echo "### Archives" >> "${summary}"
published="${RUNNER_TEMP}/published-SHA256.txt"
curl -fsSL "https://github.com/hermeticbuild/hermetic-llvm/releases/download/${tag}/SHA256.txt" -o "${published}"
echo "| Archive | Published | Rebuilt | Result |" >> "${summary}"
echo "| --- | --- | --- | --- |" >> "${summary}"
while read -r expected name; do
  actual="$(awk -v n="${name}" '$2 == n {print $1}' release/SHA256.txt)"
  if [[ "${actual}" == "${expected}" ]]; then
    result="✅ identical"
  elif [[ -n "${actual}" ]] && same_except_pe_timestamps "${name}"; then
    result="✅ identical except the link time in Windows executables"
  else
    result="❌ different"
    echo "::error::${name} differs from the published archive (published ${expected}, rebuilt ${actual:-missing})"
    failed=1
  fi
  echo "| ${name} | \`${expected:0:12}\` | \`${actual:0:12}\` | ${result} |" >> "${summary}"
done < "${published}"
if [[ "$(wc -l < release/SHA256.txt)" != "$(wc -l < "${published}")" ]]; then
  echo "::error::The rebuild produced a different set of archives than the release"
  failed=1
fi

exit "${failed}"
