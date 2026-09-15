#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

assert_contains() {
  local file="$1"
  local value="$2"
  grep -Fq -- "${value}" "${file}" || fail "${file} does not contain: ${value}"
}

assert_absent() {
  local file="$1"
  local value="$2"
  if grep -Fq -- "${value}" "${file}"; then
    fail "${file} unexpectedly contains: ${value}"
  fi
}

assert_command_absent() {
  local file="$1"
  local value="$2"
  if sed -n '/Command Line:/,$p' "${file}" | grep -Fq -- "${value}"; then
    fail "${file} command unexpectedly contains: ${value}"
  fi
}

assert_matches() {
  local file="$1"
  local pattern="$2"
  grep -Eq -- "${pattern}" "${file}" || fail "${file} does not match: ${pattern}"
}

assert_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line
  local second_line
  first_line="$(grep -Fnm1 -- "${first}" "${file}" | cut -d: -f1 || true)"
  second_line="$(grep -Fnm1 -- "${second}" "${file}" | cut -d: -f1 || true)"
  [[ -n "${first_line}" && -n "${second_line}" && "${first_line}" -lt "${second_line}" ]] ||
    fail "${file} does not order ${first} before ${second}"
}

action_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/windows-msvc-actions.XXXXXX")"
common_flags=(
  "$@"
  --platforms=@llvm//platforms:windows_x86_64_msvc
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
)
mingw_flags=(
  "$@"
  --platforms=@llvm//platforms:windows_x86_64
)

bazel --bazelrc=.bazelrc aquery "${mingw_flags[@]}" \
  --features=-compiler_param_file \
  --output=commands \
  'inputs(".*libcxx/src/algorithm.cpp", mnemonic("CppCompile", deps(@llvm-project//libcxx:libcxx)))' \
  >"${action_dir}/mingw-libcxx-compile.txt"
bazel --bazelrc=.bazelrc aquery "${mingw_flags[@]}" \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_test)' \
  >"${action_dir}/stage1-mingw-compile.txt"
bazel --bazelrc=.bazelrc aquery "${mingw_flags[@]}" \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppLink", //:windows_test)' \
  >"${action_dir}/mingw-link.txt"
bazel --bazelrc=.bazelrc aquery "${mingw_flags[@]}" \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_test)' \
  >"${action_dir}/mingw-release-compile.txt"
bazel --bazelrc=.bazelrc aquery "${mingw_flags[@]}" \
  --features=generate_pdb_file \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_test)' \
  >"${action_dir}/mingw-pdb-compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --features=-compiler_param_file \
  --output=commands \
  'inputs(".*libcxx/src/algorithm.cpp", mnemonic("CppCompile", deps(@llvm-project//libcxx:libcxx.static.msvc_link_name)))' \
  >"${action_dir}/msvc-libcxx-compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --features=-compiler_param_file \
  --output=commands \
  'inputs(".*libcxxabi/src/private_typeinfo.cpp", mnemonic("CppCompile", deps(@llvm-project//libcxxabi:libcxxabi.static)))' \
  >"${action_dir}/release-libcxxabi-compile.txt"

bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppCompile", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/default-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  -c opt \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/opt-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  -c opt \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/release-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  -c dbg \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/dbg-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  -c opt \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_libcxx_behavior_debug)' \
  >"${action_dir}/pdb-opt-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  -c opt \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_debug)' \
  >"${action_dir}/pdb-opt-link-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppArchive", //:windows_msvc_libcxx_behavior_support)' \
  >"${action_dir}/archive.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --output=text \
  'mnemonic("ValidateStaticLibrary", deps(@llvm-project//libcxx:libcxx.static.msvc_link_name))' \
  >"${action_dir}/staged-runtime-validation.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --output=text \
  'mnemonic("ValidateStaticLibrary", deps(//:comm_symbol_static_lib))' \
  >"${action_dir}/complete-runtime-validation.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/link.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-compile.txt"
for source_action in \
  "raw-assembly:windows_msvc_raw_assembly_x86_64[.]s" \
  "preprocessed-assembly:windows_msvc_assembly[.]S" \
  "c:windows_msvc_c_smoke[.]c" \
  "cxx:windows_msvc_libcxx_behavior[.]cc"; do
  action_name="${source_action%%:*}"
  source_pattern="${source_action#*:}"
  bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
    --features=thin_lto \
    --features=-compiler_param_file \
    --output=commands \
    "inputs(\"${source_pattern}\", mnemonic(\"CppCompile\", //:windows_msvc_libcxx_behavior_md))" \
    >"${action_dir}/${action_name}-compile.txt"
done
for compilation_mode in opt dbg; do
  bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
    -c "${compilation_mode}" \
    --features=-compiler_param_file \
    --output=commands \
    'inputs("windows_msvc_raw_assembly_x86_64[.]s", mnemonic("CppCompile", //:windows_msvc_libcxx_behavior_md))' \
    >"${action_dir}/raw-assembly-${compilation_mode}-compile.txt"
done
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --include_param_files \
  --output=text \
  'mnemonic("CppLTOIndexing", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-index.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --include_param_files \
  --output=text \
  'mnemonic("CcLtoBackendCompile", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-backend.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=no_exceptions \
  --features=no_rtti \
  --features=omit_frame_pointer \
  --include_param_files \
  --output=text \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-link.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=-dynamic_link_msvcrt \
  --features=static_link_msvcrt \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --features=-compiler_param_file \
  --output=commands \
  'inputs(".*libcxx/src/locale.cpp", mnemonic("CppCompile", deps(@llvm-project//libcxx:libcxx.static.msvc_link_name)))' \
  >"${action_dir}/stage1-libcxx-compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=-dynamic_link_msvcrt \
  --features=static_link_msvcrt \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --include_param_files \
  --output=text \
  'mnemonic("CppLTOIndexing", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/stage1-thin-lto-index.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --features=-dynamic_link_msvcrt \
  --features=static_link_msvcrt \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --include_param_files \
  --output=text \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/stage1-thin-lto-link.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("DefParser", //:windows_msvc_generated_def.dll)' \
  >"${action_dir}/def.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("DefParser", //:windows_msvc_generated_def_thinlto.dll)' \
  >"${action_dir}/thin-lto-def.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppLink", //:windows_msvc_generated_def.dll)' \
  >"${action_dir}/dll-link.txt"
bazel --bazelrc=.bazelrc cquery "${common_flags[@]}" \
  --dynamic_mode=off \
  --output=starlark \
  --starlark:expr='providers(target)' \
  '@llvm-project//clang:config' \
  >"${action_dir}/clang-static-config.txt"
bazel --bazelrc=.bazelrc cquery "${common_flags[@]}" \
  --dynamic_mode=default \
  --output=starlark \
  --starlark:expr='providers(target)' \
  '@llvm-project//clang:config' \
  >"${action_dir}/clang-dynamic-config.txt"
bazel --bazelrc=.bazelrc cquery "${common_flags[@]}" \
  --output=label \
  'kind("source file", deps(@llvm-project//llvm:Support))' \
  >"${action_dir}/llvm-support-sources.txt"
bazel --bazelrc=.bazelrc cquery "${common_flags[@]}" \
  --output=label \
  'kind(".*cc_toolchain.*", deps(//:windows_msvc_crt_default_probe))' \
  >"${action_dir}/resolved-toolchains.txt"
bazel --bazelrc=.bazelrc build "${common_flags[@]}" \
  --features=-dynamic_link_msvcrt \
  --features=static_link_msvcrt \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  //:windows_msvc_thinlto_weak_alias

assert_matches "${action_dir}/resolved-toolchains.txt" "@llvm_toolchains//:linux_(aarch64|x86_64)_cc_toolchain"
assert_absent "${action_dir}/resolved-toolchains.txt" "_msvc_cc_toolchain"

assert_contains "${action_dir}/compile.txt" "clang-cl"
assert_contains "${action_dir}/compile.txt" "/MD"
assert_contains "${action_dir}/compile.txt" ".d"
assert_contains "${action_dir}/compile.txt" ".params"
assert_contains "${action_dir}/compile.txt" "libcxx_headers_include_search_directory"
assert_contains "${action_dir}/compile.txt" "msvc_com_support_headers_source"
assert_contains "${action_dir}/compile.txt" "msvc_sdk_header_case_overlay.yaml"
assert_absent "${action_dir}/compile.txt" "clang++"
assert_absent "${action_dir}/compile.txt" "-fPIC"
assert_absent "${action_dir}/compile.txt" "/std:c++20"
assert_absent "${action_dir}/compile.txt" "msvc_include"

assert_contains "${action_dir}/mingw-libcxx-compile.txt" "-Wno-pragma-pack"
assert_contains "${action_dir}/mingw-libcxx-compile.txt" "-Wno-unused-value"
assert_contains "${action_dir}/mingw-libcxx-compile.txt" "-Xclang=-Wno-thread-safety-analysis"
assert_contains "${action_dir}/mingw-libcxx-compile.txt" "-nobuiltininc"
assert_matches "${action_dir}/mingw-libcxx-compile.txt" "mingw-w64-headers/crt.* -nobuiltininc -Xclang -internal-isystem -Xclang .*lib/clang/[0-9]+/include"
assert_absent "${action_dir}/mingw-libcxx-compile.txt" "/clang:-Wno-pragma-pack"
assert_absent "${action_dir}/mingw-libcxx-compile.txt" "/clang:-Wno-unused-value"
assert_matches "${action_dir}/stage1-mingw-compile.txt" "stage1_linux_(x86_64|aarch64)/bin/clang\\+\\+"
assert_contains "${action_dir}/stage1-mingw-compile.txt" "-nobuiltininc"
assert_matches "${action_dir}/stage1-mingw-compile.txt" "mingw-w64-headers/crt.* -nobuiltininc -Xclang -internal-isystem -Xclang .*stage1_linux_(x86_64|aarch64)/lib/clang/[0-9]+/include"
assert_contains "${action_dir}/mingw-link.txt" "-Wl,--no-insert-timestamp"
assert_contains "${action_dir}/mingw-release-compile.txt" "-fno-exceptions"
assert_contains "${action_dir}/mingw-release-compile.txt" "-fno-rtti"
assert_contains "${action_dir}/mingw-release-compile.txt" "-fomit-frame-pointer"
assert_absent "${action_dir}/mingw-release-compile.txt" "/EHs-c-"
assert_absent "${action_dir}/mingw-release-compile.txt" "/clang:-fno-rtti"
assert_contains "${action_dir}/mingw-pdb-compile.txt" "-gcodeview"
assert_absent "${action_dir}/mingw-pdb-compile.txt" "/Z7"
assert_contains "${action_dir}/msvc-libcxx-compile.txt" "bin/clang-cl"
assert_matches "${action_dir}/msvc-libcxx-compile.txt" "/clang:-Wthread-safety.*-Xclang=-Wno-thread-safety-analysis"
assert_absent "${action_dir}/msvc-libcxx-compile.txt" "/clang:-flto=thin"
assert_absent "${action_dir}/msvc-libcxx-compile.txt" "/clang:-fthin-link-bitcode="
assert_absent "${action_dir}/msvc-libcxx-compile.txt" "/EHs-c-"
assert_absent "${action_dir}/msvc-libcxx-compile.txt" "/clang:-fno-rtti"
assert_absent "${action_dir}/msvc-libcxx-compile.txt" "/clang:-fomit-frame-pointer"

assert_contains "${action_dir}/release-libcxxabi-compile.txt" "libcxxabi/src/private_typeinfo.cpp"
assert_contains "${action_dir}/release-libcxxabi-compile.txt" "-funwind-tables"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" " -fno-exceptions"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" " -fno-rtti"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" " -fomit-frame-pointer"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" "/EHs-c-"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" "/clang:-fno-rtti"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" "/clang:-fomit-frame-pointer"

assert_contains "${action_dir}/clang-static-config.txt" "CLANG_BUILD_STATIC"
assert_contains "${action_dir}/clang-static-config.txt" "clang/Config/config.h"
assert_contains "${action_dir}/clang-dynamic-config.txt" "CLANG_BUILD_STATIC"
assert_contains "${action_dir}/clang-dynamic-config.txt" "clang/Config/config.h"

for blake3_implementation in avx2 avx512 sse2 sse41; do
  assert_contains "${action_dir}/llvm-support-sources.txt" "blake3_${blake3_implementation}_x86-64_windows_gnu.S"
  assert_absent "${action_dir}/llvm-support-sources.txt" "blake3_${blake3_implementation}_x86-64_unix.S"
done

assert_contains "${action_dir}/default-compile-flags.txt" "/std:c++17"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-fms-compatibility-version="
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-nostdlibinc"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-nobuiltininc"
assert_matches "${action_dir}/default-compile-flags.txt" "libcxx_headers_include_search_directory.* /clang:-nobuiltininc /imsvc[^ ]*/lib/clang/[0-9]+/include.*msvc_vcruntime_headers_source"
assert_contains "${action_dir}/default-compile-flags.txt" "/nologo"
assert_contains "${action_dir}/default-compile-flags.txt" "/Brepro"
assert_contains "${action_dir}/default-compile-flags.txt" "/EHsc"
assert_contains "${action_dir}/default-compile-flags.txt" "/GR"
assert_absent "${action_dir}/default-compile-flags.txt" "/bigobj"
assert_contains "${action_dir}/default-compile-flags.txt" "/DNOMINMAX"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-gno-codeview-command-line"
assert_absent "${action_dir}/default-compile-flags.txt" "/D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS"
assert_contains "${action_dir}/default-compile-flags.txt" "/GS"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-Wall"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-Wthread-safety"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-fcolor-diagnostics"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-fno-omit-frame-pointer"
assert_absent "${action_dir}/default-compile-flags.txt" "/Z7"
assert_contains "${action_dir}/opt-compile-flags.txt" "/O2"
assert_contains "${action_dir}/opt-compile-flags.txt" "/DNDEBUG"
assert_contains "${action_dir}/opt-compile-flags.txt" "/Gy"
assert_contains "${action_dir}/opt-compile-flags.txt" "/Gw"
assert_contains "${action_dir}/opt-compile-flags.txt" "/Zc:inline"
assert_absent "${action_dir}/opt-compile-flags.txt" "/Z7"
assert_absent "${action_dir}/opt-compile-flags.txt" "/D_DEBUG"
assert_contains "${action_dir}/release-compile-flags.txt" "/EHs-c-"
assert_contains "${action_dir}/release-compile-flags.txt" "/clang:-fno-rtti"
assert_contains "${action_dir}/release-compile-flags.txt" "/clang:-fomit-frame-pointer"
assert_matches "${action_dir}/release-compile-flags.txt" "/EHsc .* /EHs-c-"
assert_matches "${action_dir}/release-compile-flags.txt" "/GR .* /clang:-fno-rtti"
assert_matches "${action_dir}/release-compile-flags.txt" "/clang:-fno-omit-frame-pointer .* /clang:-fomit-frame-pointer"
assert_absent "${action_dir}/release-compile-flags.txt" " -fno-exceptions"
assert_absent "${action_dir}/release-compile-flags.txt" " -fno-rtti"
assert_absent "${action_dir}/release-compile-flags.txt" " -fomit-frame-pointer"
assert_contains "${action_dir}/dbg-compile-flags.txt" "/Od"
assert_contains "${action_dir}/dbg-compile-flags.txt" "/Z7"
assert_absent "${action_dir}/dbg-compile-flags.txt" "/O2"
assert_absent "${action_dir}/dbg-compile-flags.txt" "/DNDEBUG"
assert_absent "${action_dir}/dbg-compile-flags.txt" "/D_DEBUG"
assert_contains "${action_dir}/pdb-opt-compile-flags.txt" "/O2"
assert_contains "${action_dir}/pdb-opt-compile-flags.txt" "/Z7"
assert_absent "${action_dir}/pdb-opt-compile-flags.txt" "-gcodeview"
assert_contains "${action_dir}/pdb-opt-link-flags.txt" "/clang:/DEBUG"
assert_contains "${action_dir}/archive.txt" "llvm-ar"
assert_contains "${action_dir}/archive.txt" "rcsD"
assert_contains "${action_dir}/archive.txt" "windows_msvc_libcxx_behavior_support.lib"
assert_absent "${action_dir}/archive.txt" "llvm-lib"
assert_absent "${action_dir}/staged-runtime-validation.txt" "Mnemonic: ValidateStaticLibrary"
assert_contains "${action_dir}/complete-runtime-validation.txt" "Mnemonic: ValidateStaticLibrary"
assert_contains "${action_dir}/complete-runtime-validation.txt" "static-library-validator"

assert_contains "${action_dir}/link.txt" "bin/clang-cl"
assert_contains "${action_dir}/link.txt" "bin/lld-link"
assert_contains "${action_dir}/link.txt" "/clang:-fuse-ld=lld"
assert_contains "${action_dir}/link.txt" "LIB=__hermetic_llvm_empty_lib__"
assert_contains "${action_dir}/link.txt" "-resource-dir="
assert_contains "${action_dir}/link.txt" "-rtlib=compiler-rt"
assert_contains "${action_dir}/link.txt" "resource_directory_default"
assert_contains "${action_dir}/link.txt" "libcxx_msvc_library_search_directory"
assert_contains "${action_dir}/link.txt" "msvc_com_support_libraries"
assert_contains "${action_dir}/link.txt" "/clang:-Xlinker"
assert_contains "${action_dir}/link.txt" "/clang:/vfsoverlay:"
assert_contains "${action_dir}/link.txt" "msvc_sdk_library_case_overlay.yaml"
assert_contains "${action_dir}/link.txt" "/c/ucrt/x64/libucrt.lib"
assert_contains "${action_dir}/link.txt" "/c/um/x64/kernel32.Lib"
assert_contains "${action_dir}/link.txt" "/clang:/MACHINE:X64"
assert_contains "${action_dir}/link.txt" "/Brepro"
assert_contains "${action_dir}/link.txt" "/clang:/INCREMENTAL:NO"
assert_contains "${action_dir}/link.txt" "/clang:/lldignoreenv"
assert_contains "${action_dir}/link.txt" "/clang:/PDBALTPATH:%_PDB%"
assert_contains "${action_dir}/link.txt" "/clang:/pdbsourcepath:."
assert_contains "${action_dir}/link.txt" "/clang:/SUBSYSTEM:CONSOLE"
assert_contains "${action_dir}/link.txt" "/clang:/WHOLEARCHIVE:"
assert_contains "${action_dir}/link.txt" "/clang:/OPT:REF"
assert_contains "${action_dir}/link.txt" "/Fe"
assert_before "${action_dir}/link.txt" "/clang:/DEBUG:NONE" "/clang:/OPT:REF"
assert_before "${action_dir}/link.txt" "/clang:/OPT:REF" "/Fe"
assert_absent "${action_dir}/link.txt" "/NODEFAULTLIB"
assert_contains "${action_dir}/link.txt" "/clang:/DEFAULTLIB:libc++.lib"
assert_before "${action_dir}/link.txt" "libcxx_msvc_library_search_directory" "/clang:/DEFAULTLIB:libc++.lib"
assert_absent "${action_dir}/link.txt" "clang_rt.builtins.lib"
assert_command_absent "${action_dir}/link.txt" "msvcrt.lib"
assert_command_absent "${action_dir}/link.txt" "msvcprt.lib"
assert_absent "${action_dir}/link.txt" "libc++.dll"
assert_absent "${action_dir}/link.txt" "libclang_rt.builtins.a"
assert_absent "${action_dir}/link.txt" "msvc_lib_arm64"
assert_absent "${action_dir}/link.txt" "msvc_lib_x64"
assert_absent "${action_dir}/link.txt" "-Wl,"

assert_contains "${action_dir}/thin-lto-compile.txt" "bin/clang-cl"
assert_contains "${action_dir}/thin-lto-compile.txt" "--target=x86_64-pc-windows-msvc"
assert_contains "${action_dir}/thin-lto-compile.txt" "/std:c++17"
assert_contains "${action_dir}/thin-lto-compile.txt" "/clang:-flto=thin"
assert_contains "${action_dir}/thin-lto-compile.txt" "/Fo"
assert_contains "${action_dir}/thin-lto-compile.txt" ".obj"
assert_contains "${action_dir}/thin-lto-compile.txt" "/clang:-fthin-link-bitcode="
assert_contains "${action_dir}/thin-lto-compile.txt" "/EHs-c-"
assert_contains "${action_dir}/thin-lto-compile.txt" "/clang:-fno-rtti"
assert_contains "${action_dir}/thin-lto-compile.txt" ".indexing.o"
assert_absent "${action_dir}/thin-lto-compile.txt" ".indexing.obj"
assert_absent "${action_dir}/thin-lto-compile.txt" "/std:c++20"

assert_contains "${action_dir}/raw-assembly-compile.txt" "--target=x86_64-pc-windows-msvc"
assert_contains "${action_dir}/raw-assembly-compile.txt" "/Brepro"
assert_contains "${action_dir}/raw-assembly-compile.txt" "/nologo"
assert_contains "${action_dir}/raw-assembly-compile.txt" "/c windows_msvc_raw_assembly_x86_64.s"
assert_contains "${action_dir}/raw-assembly-compile.txt" "/Fo"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-fms-compatibility-version="
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-no-canonical-prefixes"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/D__DATE__="
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-gno-codeview-command-line"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-nostdlibinc"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/D_CRT_"
assert_absent "${action_dir}/raw-assembly-compile.txt" "libcxx_headers_include_search_directory"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/DNOMINMAX"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-ivfsoverlay"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/imsvc"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/EHsc"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/GR"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/GS"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-Wall"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-fcolor-diagnostics"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-fno-omit-frame-pointer"
assert_absent "${action_dir}/raw-assembly-compile.txt" "/clang:-MD"
assert_absent "${action_dir}/raw-assembly-opt-compile.txt" "/O2"
assert_absent "${action_dir}/raw-assembly-opt-compile.txt" "/DNDEBUG"
assert_absent "${action_dir}/raw-assembly-opt-compile.txt" "/Gy"
assert_absent "${action_dir}/raw-assembly-opt-compile.txt" "/Gw"
assert_absent "${action_dir}/raw-assembly-opt-compile.txt" "/Zc:inline"
assert_absent "${action_dir}/raw-assembly-dbg-compile.txt" "/Od"
assert_absent "${action_dir}/raw-assembly-dbg-compile.txt" "/Z7"

assert_contains "${action_dir}/preprocessed-assembly-compile.txt" "/clang:-fms-compatibility-version="
assert_contains "${action_dir}/preprocessed-assembly-compile.txt" "/clang:-nostdlibinc"
assert_contains "${action_dir}/preprocessed-assembly-compile.txt" "/DNOMINMAX"
assert_contains "${action_dir}/preprocessed-assembly-compile.txt" "/clang:-ivfsoverlay"
assert_contains "${action_dir}/preprocessed-assembly-compile.txt" "/imsvc"
assert_contains "${action_dir}/preprocessed-assembly-compile.txt" "/clang:-MD"
assert_absent "${action_dir}/preprocessed-assembly-compile.txt" "libcxx_headers_include_search_directory"
assert_absent "${action_dir}/preprocessed-assembly-compile.txt" "/EHsc"
assert_absent "${action_dir}/preprocessed-assembly-compile.txt" "/GR"
assert_absent "${action_dir}/preprocessed-assembly-compile.txt" "/GS"
assert_absent "${action_dir}/preprocessed-assembly-compile.txt" "/clang:-fno-omit-frame-pointer"

assert_contains "${action_dir}/c-compile.txt" "/DNOMINMAX"
assert_contains "${action_dir}/c-compile.txt" "/clang:-ivfsoverlay"
assert_contains "${action_dir}/c-compile.txt" "/GS"
assert_contains "${action_dir}/c-compile.txt" "/clang:-fno-omit-frame-pointer"
assert_absent "${action_dir}/c-compile.txt" "libcxx_headers_include_search_directory"
assert_absent "${action_dir}/c-compile.txt" "/EHsc"
assert_absent "${action_dir}/c-compile.txt" "/GR"

assert_contains "${action_dir}/cxx-compile.txt" "libcxx_headers_include_search_directory"
assert_contains "${action_dir}/cxx-compile.txt" "/EHsc"
assert_contains "${action_dir}/cxx-compile.txt" "/GR"
assert_contains "${action_dir}/cxx-compile.txt" "/GS"
assert_contains "${action_dir}/cxx-compile.txt" "/clang:-fno-omit-frame-pointer"

assert_contains "${action_dir}/thin-lto-index.txt" "CppLTOIndexing"
assert_matches "${action_dir}/thin-lto-index.txt" "Command Line: \\(exec .*llvm-toolchain-minimal-linux-(amd64|arm64)/bin/clang-cl"
assert_matches "${action_dir}/thin-lto-index.txt" "llvm-toolchain-minimal-linux-(amd64|arm64)/bin/lld-link"
assert_absent "${action_dir}/thin-lto-index.txt" "clang-cl-thinlto-index"
assert_absent "${action_dir}/thin-lto-index.txt" "COMPILER_PATH="
assert_absent "${action_dir}/thin-lto-index.txt" "LLVM_CLANG_CL="
assert_absent "${action_dir}/thin-lto-index.txt" "LLVM_LLD_LINK="
assert_absent "${action_dir}/thin-lto-index.txt" "thinlto_index/bin"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/MACHINE:X64"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/vfsoverlay:"
assert_contains "${action_dir}/thin-lto-index.txt" "msvc_sdk_library_case_overlay.yaml"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-index-only:"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-emit-imports-files"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-prefix-replace:"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-object-suffix-replace:.indexing.o;.obj"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/lto-obj-path:"
assert_contains "${action_dir}/thin-lto-index.txt" ".lto.merged.o"
assert_contains "${action_dir}/thin-lto-index.txt" ".indexing.o"
assert_absent "${action_dir}/thin-lto-index.txt" ".indexing.obj"
assert_absent "${action_dir}/thin-lto-index.txt" "-Wl,"
assert_absent "${action_dir}/thin-lto-index.txt" " -o "
assert_absent "${action_dir}/thin-lto-index.txt" "-x ir"

assert_matches "${action_dir}/stage1-libcxx-compile.txt" "stage1_linux_(x86_64|aarch64)/bin/clang-cl"
assert_contains "${action_dir}/stage1-libcxx-compile.txt" "--target=x86_64-pc-windows-msvc"
assert_contains "${action_dir}/stage1-libcxx-compile.txt" "/MT"
assert_contains "${action_dir}/stage1-libcxx-compile.txt" "/clang:-nobuiltininc"
assert_matches "${action_dir}/stage1-libcxx-compile.txt" "/clang:-nobuiltininc /imsvc.*stage1_linux_(x86_64|aarch64)/lib/clang/[0-9]+/include.*msvc_vcruntime_headers_source"
assert_contains "${action_dir}/stage1-libcxx-compile.txt" "msvc_com_support_headers_source"
assert_contains "${action_dir}/stage1-libcxx-compile.txt" "msvc_vcruntime_headers_source"
assert_contains "${action_dir}/stage1-libcxx-compile.txt" "windows_sdk/sysroot/base/c/Include"
assert_contains "${action_dir}/stage1-libcxx-compile.txt" "msvc_sdk_header_case_overlay.yaml"
assert_matches "${action_dir}/stage1-thin-lto-index.txt" "Command Line: \\(exec .*stage1_linux_(x86_64|aarch64)/bin/clang-cl"
assert_matches "${action_dir}/stage1-thin-lto-index.txt" "stage1_linux_(x86_64|aarch64)/bin/lld-link"
assert_absent "${action_dir}/stage1-thin-lto-index.txt" "llvm-toolchain-minimal"
assert_matches "${action_dir}/stage1-thin-lto-link.txt" "Command Line: \\(exec .*stage1_linux_(x86_64|aarch64)/bin/clang-cl"
assert_matches "${action_dir}/stage1-thin-lto-link.txt" "stage1_linux_(x86_64|aarch64)/bin/lld-link"
assert_contains "${action_dir}/stage1-thin-lto-link.txt" "/MT"
assert_contains "${action_dir}/stage1-thin-lto-link.txt" "msvc_static_runtime_libraries"
assert_absent "${action_dir}/stage1-thin-lto-link.txt" "llvm-toolchain-minimal"

assert_contains "${action_dir}/thin-lto-backend.txt" "CcLtoBackendCompile"
assert_contains "${action_dir}/thin-lto-backend.txt" "bin/clang-cl"
assert_contains "${action_dir}/thin-lto-backend.txt" "/clang:-fthinlto-index="
assert_contains "${action_dir}/thin-lto-backend.txt" "windows_msvc_libcxx_behavior.obj"
assert_contains "${action_dir}/thin-lto-backend.txt" "/clang:-fomit-frame-pointer"
assert_absent "${action_dir}/thin-lto-backend.txt" "/clang:-nostdlibinc"
assert_absent "${action_dir}/thin-lto-backend.txt" "/clang:-nobuiltininc"
assert_absent "${action_dir}/thin-lto-backend.txt" "/imsvc"
assert_absent "${action_dir}/thin-lto-backend.txt" "/EHsc"
assert_absent "${action_dir}/thin-lto-backend.txt" "/GR"
assert_absent "${action_dir}/thin-lto-backend.txt" "/GS"
assert_absent "${action_dir}/thin-lto-backend.txt" "/DNOMINMAX"
assert_absent "${action_dir}/thin-lto-backend.txt" "/clang:-ivfsoverlay"
assert_absent "${action_dir}/thin-lto-backend.txt" "/clang:-gno-codeview-command-line"
assert_absent "${action_dir}/thin-lto-backend.txt" ".indexing.o"
assert_absent "${action_dir}/thin-lto-backend.txt" "-Wl,"
assert_absent "${action_dir}/thin-lto-backend.txt" " -o "
assert_absent "${action_dir}/thin-lto-backend.txt" "-x ir"

assert_contains "${action_dir}/thin-lto-link.txt" "bin/clang-cl"
assert_contains "${action_dir}/thin-lto-link.txt" "bin/lld-link"
assert_contains "${action_dir}/thin-lto-link.txt" "/clang:/MACHINE:X64"
assert_contains "${action_dir}/thin-lto-link.txt" "/clang:/vfsoverlay:"
assert_contains "${action_dir}/thin-lto-link.txt" "msvc_sdk_library_case_overlay.yaml"
assert_contains "${action_dir}/thin-lto-link.txt" ".exe-lto-final.params"
assert_contains "${action_dir}/thin-lto-link.txt" ".lto.merged.o"
assert_contains "${action_dir}/thin-lto-link.txt" "/Fe"
assert_matches "${action_dir}/thin-lto-link.txt" "Command Line: \\(exec .*bin/clang-cl"
assert_absent "${action_dir}/thin-lto-link.txt" "-Wl,"
assert_absent "${action_dir}/thin-lto-link.txt" " -o "
assert_absent "${action_dir}/thin-lto-link.txt" "-x ir"

assert_contains "${action_dir}/def.txt" "DefParser"
assert_contains "${action_dir}/def.txt" "def_file_generator"
assert_contains "${action_dir}/def.txt" "bin/llvm-nm"
assert_contains "${action_dir}/def.txt" ".gen.def"
assert_contains "${action_dir}/thin-lto-def.txt" "def_file_generator"
assert_contains "${action_dir}/thin-lto-def.txt" "bin/llvm-nm"
assert_contains "${action_dir}/thin-lto-def.txt" "windows_generated_def.obj"
assert_contains "${action_dir}/dll-link.txt" "/clang:/DEF:"
assert_contains "${action_dir}/dll-link.txt" "/clang:/IMPLIB:"
assert_contains "${action_dir}/dll-link.txt" "/clang:/DLL"
assert_contains "${action_dir}/dll-link.txt" ".if.lib"
