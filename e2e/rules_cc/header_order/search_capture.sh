#!/usr/bin/env bash
set -euo pipefail

search=$1
stderr=$2
preprocessed=$3
shift 3
compiler=$1
shift

args=()
saw_compile=0
saw_output=0
while (($#)); do
  case "$1" in
    -c|/c)
      saw_compile=$((saw_compile + 1))
      shift
      ;;
    -MD|/clang:-MD)
      shift
      ;;
    -MF|/clang:-MF)
      shift 2
      ;;
    -o)
      saw_output=$((saw_output + 1))
      shift 2
      ;;
    /Fo*)
      saw_output=$((saw_output + 1))
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
if ((saw_compile != 1 || saw_output != 1)); then
  printf 'Expected exactly one compile action and output flag\n' >&2
  exit 1
fi

if [[ "$compiler" == *clang-cl || "$compiler" == *clang-cl.exe ]]; then
  if ! "$compiler" "${args[@]}" /E /clang:-v > "$preprocessed" 2> "$stderr"; then
    cat "$stderr" >&2
    exit 1
  fi
else
  if ! "$compiler" "${args[@]}" -E -v -o "$preprocessed" 2> "$stderr"; then
    cat "$stderr" >&2
    exit 1
  fi
fi

if ! awk '
  /^#include <\.\.\.> search starts here:$/ { inside = 1; count++; next }
  /^End of search list\.$/ { if (inside) { inside = 0; ended++ }; next }
  inside { sub(/^ /, ""); print }
  END { if (count != 1 || ended != 1) exit 1 }
' "$stderr" > "$search.raw"; then
  cat "$stderr" >&2
  exit 1
fi

generated_bin=${search%%/bin/*}/bin
while IFS= read -r path; do
  path=${path//\\//}
  case "$path" in
    .) role=workspace-root ;;
    header_order/include) role=user-system ;;
    external/external_include_paths_test+) role=external-package-root ;;
    external/external_include_paths_test+/builtin_include) role=external-user ;;
    "$generated_bin") role=generated-bin ;;
    "$generated_bin/external/llvm+") role=generated-llvm-root ;;
    "$generated_bin/external/external_include_paths_test+") role=generated-external-package ;;
    "$generated_bin/external/llvm++llvm+llvm-project/libcxx/libcxx_public_headers") role=cxx-public ;;
    "$generated_bin/external/llvm++llvm+llvm-project/libcxx/libcxx_detail_headers") role=cxx-detail ;;
    "$generated_bin/external/llvm++llvm+llvm-project/libcxxabi/libcxxabi_headers_include_search_directory") role=cxx-abi ;;
    "$generated_bin/external/llvm++llvm+llvm-project/libcxx/libcxx_headers_include_search_directory") role=cxx-merged ;;
    "$generated_bin"/external/llvm++gcc+gcc_*/headers_include_search_directory) role=libstdcxx ;;
    "$generated_bin"/external/llvm++gcc+gcc_*/generated_host_headers_include_search_directory) role=libstdcxx-host ;;
    "$generated_bin/external/llvm+/runtimes/cxxstdlib/macos_cxx_public_headers") role=cxx-public ;;
    "$generated_bin/external/llvm+/runtimes/cxxstdlib/macos_cxx_detail_headers") role=cxx-detail ;;
    external/llvm++llvm_toolchain_minimal+llvm-toolchain-minimal-*/lib/clang/*/include) role=builtin ;;
    external/llvm++llvm_toolchain_minimal+llvm-toolchain-minimal-*/lib/clang/*/include/cuda_wrappers) role=cuda-wrappers ;;
    external/llvm++kernel_headers+linux_kernel_headers_*/include) role=linux-kernel ;;
    external/llvm++glibc+glibc_headers_*/include) role=glibc ;;
    "$generated_bin"/external/llvm++musl+musl_libc/generated/*/includes) role=musl ;;
    external/llvm++llvm+llvm-project/compiler-rt/include) role=sanitizer ;;
    external/llvm++mingw+mingw/mingw-w64-libraries/winpthreads/include) role=winpthreads ;;
    "$generated_bin/external/llvm++mingw+mingw/mingw-w64-headers/crt") role=mingw-generated-crt ;;
    external/llvm++mingw+mingw/mingw-w64-headers/include) role=mingw-sdk ;;
    external/llvm++mingw+mingw/mingw-w64-headers/crt) role=mingw-crt ;;
    "$generated_bin/external/llvm+/runtimes/msvc/msvc_com_support_headers_source") role=msvc-com ;;
    "$generated_bin/external/llvm+/runtimes/msvc/msvc_vcruntime_headers_source") role=msvc-vcruntime ;;
    external/windows_support++msvc_runtime+msvc_runtime/sysroot/Contents/VC/Tools/MSVC/*/include) role=msvc-stl ;;
    external/windows_support++windows_sdk+windows_sdk/sysroot/base/c/Include/*/ucrt) role=windows-ucrt ;;
    external/windows_support++windows_sdk+windows_sdk/sysroot/base/c/Include/*/shared) role=windows-shared ;;
    external/windows_support++windows_sdk+windows_sdk/sysroot/base/c/Include/*/um) role=windows-um ;;
    external/windows_support++windows_sdk+windows_sdk/sysroot/base/c/Include/*/winrt) role=windows-winrt ;;
    external/llvm++osx+macos_sdk/sysroot/usr/include) role=macos-libc ;;
    'external/llvm++osx+macos_sdk/sysroot/System/Library/Frameworks (framework directory)') role='macos-frameworks (framework directory)' ;;
    *)
      printf 'Unrecognized Clang search root: %s\n' "$path" >&2
      exit 1
      ;;
  esac
  printf '%s\n' "$role"
done < "$search.raw" > "$search"
