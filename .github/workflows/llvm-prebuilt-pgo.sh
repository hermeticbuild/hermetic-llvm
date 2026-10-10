#!/usr/bin/env bash
# Builds the LLVM prebuilts with FDO profiles trained on a host of their own
# platform, used by llvm-prebuilt-pgo.yml.
#
#   llvm-prebuilt-pgo.sh matrix "<host>..."  Prints the GitHub Actions matrices.
#   llvm-prebuilt-pgo.sh stage2 <host>       Builds the instrumented Stage 2 for
#                                            <host> (Linux, BuildBuddy RBE).
#   llvm-prebuilt-pgo.sh train <host> <dir> <shard> <shards>
#                                            Trains shard <shard> of <shards>
#                                            with the Stage 2 archive in <dir>
#                                            (on a <host> runner).
#   llvm-prebuilt-pgo.sh stage3 <host>       Builds the release archives of
#                                            <host> (Linux, BuildBuddy RBE).
#   llvm-prebuilt-pgo.sh checksums <dir>     Writes <dir>/SHA256.txt.
#
# Outputs go to release/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

# Hosts. For each one:
#   training        "host": trained by the workflow on runners of the host.
#                   "buildbuddy": trained on BuildBuddy workers of the host
#                   inside the Stage 3 build.
#   runner          GitHub runner that trains ("host" training).
#   shards          Number of runners that each train a share of the training
#                   units ("host" training).
#   exec_platform   Platform the instrumented Stage 2 runs on ("host" training).
#   stage0          Prebuilt Stage 0 repository the Stage 2 archive replaces on
#                   the runner ("host" training).
#   executor        Training executor in //toolchain/bootstrap/stage3.
#   releases        Release archives built with the host's profile, as
#                   <//prebuilt/llvm:for_* suffix>=<archive suffix>. macOS x86_64
#                   and Windows arm64 reuse the profile of the other architecture:
#                   the training cross-compiles to every target on any host, and
#                   the function names match.
host_field() {
  local host="$1" field="$2"
  case "${host}:${field}" in
    linux-amd64:training) echo "buildbuddy" ;;
    linux-amd64:executor) echo "linux_x86_64" ;;
    linux-amd64:releases) echo "linux_amd64_musl=linux-amd64-musl" ;;

    linux-arm64:training) echo "buildbuddy" ;;
    linux-arm64:executor) echo "linux_aarch64" ;;
    linux-arm64:releases) echo "linux_arm64_musl=linux-arm64-musl" ;;

    darwin-arm64:training) echo "host" ;;
    darwin-arm64:runner) echo "macos-15" ;;
    darwin-arm64:shards) echo "4" ;;
    darwin-arm64:exec_platform) echo "//platforms:macos_aarch64" ;;
    darwin-arm64:stage0) echo "llvm-toolchain-minimal-darwin-arm64" ;;
    darwin-arm64:executor) echo "macos_aarch64" ;;
    darwin-arm64:releases) echo "macos_arm64=darwin-arm64 macos_amd64=darwin-amd64" ;;

    windows-amd64-msvc:training) echo "host" ;;
    windows-amd64-msvc:runner) echo "windows-2025" ;;
    windows-amd64-msvc:shards) echo "6" ;;
    windows-amd64-msvc:exec_platform) echo "//platforms:windows_x86_64_msvc" ;;
    windows-amd64-msvc:stage0) echo "llvm-toolchain-minimal-windows-amd64" ;;
    windows-amd64-msvc:executor) echo "windows_x86_64" ;;
    windows-amd64-msvc:releases) echo "windows_amd64_msvc=windows-amd64-msvc windows_arm64_msvc=windows-arm64-msvc" ;;

    *)
      echo "Unknown host or field: ${host} ${field}" >&2
      exit 1
      ;;
  esac
}

llvm_version() {
  sed -n 's/^LLVM_VERSION = "\(.*\)"$/\1/p' MODULE.bazel
}

bazel_cmd() {
  local startup=(--bazelrc=.github/workflows/ci.bazelrc)
  case "$(uname -s)" in
    Linux)
      # The JVM defaults to a quarter of the runner's 16 GB, which the Stage 3
      # builds that also train on BuildBuddy outgrow. Matches llvm-prebuilt.sh.
      startup+=(--host_jvm_args=-Xmx8g)
      ;;
    MINGW* | MSYS* | CYGWIN*)
      # Keep paths short on Windows.
      startup+=(--output_user_root=C:/_bzl)
      ;;
  esac
  bazel "${startup[@]}" "$@"
}

# Execution platforms of --config=release. A later --extra_execution_platforms
# replaces them, so extending the list repeats them first.
RELEASE_EXECUTION_PLATFORMS="@rbe_platform//:rbe_linux_x86_64_musl,@rbe_platform//:rbe_linux_aarch64_musl"

BUILD_FLAGS=(
  --config=release
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
  --remote_download_outputs=toplevel
)

# Prints the output files of a target.
output_files() {
  bazel_cmd cquery "$@" --output=files 2>/dev/null
}

# Prints the matrices: hosts trained on runners, their training shards, and
# hosts trained on BuildBuddy.
cmd_matrix() {
  local host_trained=() shards=() buildbuddy_trained=() host shard count runner
  for host in $1; do
    case "$(host_field "${host}" training)" in
      host)
        runner="$(host_field "${host}" runner)"
        count="$(host_field "${host}" shards)"
        host_trained+=("$(printf '{"host":"%s"}' "${host}")")
        for ((shard = 0; shard < count; shard++)); do
          shards+=("$(printf '{"host":"%s","runner":"%s","shard":%d,"shards":%d}' "${host}" "${runner}" "${shard}" "${count}")")
        done
        ;;
      buildbuddy) buildbuddy_trained+=("$(printf '{"host":"%s"}' "${host}")") ;;
    esac
  done
  local IFS=,
  echo "host_trained=[${host_trained[*]}]"
  echo "training_shards=[${shards[*]}]"
  echo "buildbuddy_trained=[${buildbuddy_trained[*]}]"
}

cmd_stage2() {
  local host="$1"
  local target="//prebuilt/llvm:instrumented_stage2_${host}"
  # Stage 2 is instrumented only when built for an execution platform. The
  # host's platform comes last, so every action still runs on BuildBuddy.
  local flags=(
    "${BUILD_FLAGS[@]}"
    "--extra_execution_platforms=${RELEASE_EXECUTION_PLATFORMS},$(host_field "${host}" exec_platform)"
  )

  bazel_cmd build "${flags[@]}" "${target}"

  mkdir -p release
  cp "$(output_files "${flags[@]}" "${target}")" "release/stage2-${host}.tar.zst"
}

cmd_train() {
  local host="$1" archive_dir="$2" shard="$3" shards="$4"
  local stage0 build_file repo_dir
  stage0="$(host_field "${host}" stage0)"
  build_file="toolchain/llvm/llvm_release.BUILD.bazel"
  if [[ "${host}" == windows-* ]]; then
    build_file="toolchain/llvm/llvm_release_windows.BUILD.bazel"
  fi

  # Unpack the instrumented Stage 2 as the runner's Stage 0 repository.
  repo_dir="${RUNNER_TEMP:-/tmp}/stage2-${host}"
  rm -rf "${repo_dir}"
  mkdir -p "${repo_dir}"
  local tar_bin=tar
  if [[ -x /c/Windows/System32/tar.exe ]]; then
    # bsdtar: reads zstd and creates the archive's symlinks.
    tar_bin=/c/Windows/System32/tar.exe
  fi
  "${tar_bin}" -xf "${archive_dir}/stage2-${host}.tar.zst" -C "${repo_dir}"
  cp "${build_file}" "${repo_dir}/BUILD.bazel"
  touch "${repo_dir}/REPO.bazel"

  local target="//toolchain/bootstrap/stage3:llvm_fdo_profdata_$(host_field "${host}" executor)"
  local flags=(
    "${BUILD_FLAGS[@]}"
    "--override_repository=+llvm_toolchain_minimal+${stage0}=${repo_dir}"
    --//toolchain/bootstrap:fdo_training_compiler=prebuilt
    "--//toolchain/bootstrap:fdo_training_shard=${shard}/${shards}"
    # The training passes run the instrumented compiler on this host.
    # Everything else, including their target runtimes, builds on BuildBuddy.
    --strategy=LLVMFDOProfileTrain=local
  )

  bazel_cmd build "${flags[@]}" "${target}"

  mkdir -p release
  cp "$(output_files "${flags[@]}" "${target}")" "release/profile-${host}-${shard}.profdata"
}

cmd_stage3() {
  local host="$1"
  # The full bootstrap graph is large; drop it once its actions are known.
  local flags=("${BUILD_FLAGS[@]}" --discard_analysis_cache)
  if [[ "$(host_field "${host}" training)" == "host" ]]; then
    # Every training shard's profile, merged by the build.
    local shard
    for ((shard = 0; shard < $(host_field "${host}" shards); shard++)); do
      local profile="toolchain/bootstrap/external_fdo_profile/profile-${host}-${shard}.profdata"
      if [[ ! -f "${profile}" ]]; then
        echo "Missing ${profile}" >&2
        exit 1
      fi
    done
    flags+=(--//toolchain/bootstrap:use_external_fdo_profile)
  fi

  local version targets=() release
  version="$(llvm_version)"
  for release in $(host_field "${host}" releases); do
    targets+=("//prebuilt/llvm:for_${release%%=*}")
  done

  bazel_cmd build "${flags[@]}" "${targets[@]}"

  mkdir -p release
  for release in $(host_field "${host}" releases); do
    cp "$(output_files "${flags[@]}" "//prebuilt/llvm:for_${release%%=*}")" \
      "release/llvm-toolchain-minimal-${version}-${release#*=}.tar.zst"
  done
}

cmd_checksums() {
  (cd "$1" && sha256sum -- *.tar.zst > SHA256.txt && cat SHA256.txt)
}

command="$1"
shift
case "${command}" in
  matrix) cmd_matrix "$@" ;;
  stage2) cmd_stage2 "$@" ;;
  train) cmd_train "$@" ;;
  stage3) cmd_stage3 "$@" ;;
  checksums) cmd_checksums "$@" ;;
  *)
    echo "Unknown command: ${command}" >&2
    exit 1
    ;;
esac
