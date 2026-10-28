#!/usr/bin/env bash

set -euo pipefail

DEF_FILE_GENERATOR="${DEF_FILE_GENERATORS%% *}"
BIGOBJ_FIXTURE_WRITER="${BIGOBJ_FIXTURE_WRITERS%% *}"
CLANG_CL="${CLANG_CLS%% *}"
CLANGXX="${CLANGXXS%% *}"
export LLVM_NM="${LLVM_NMS%% *}"

test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/def-file-generator.XXXXXX")"
trap 'rm -rf "${test_tmp}"' EXIT

expect_failure() {
  local expected_message="$1"
  shift
  set +e
  "$@" >"${test_tmp}/stdout" 2>"${test_tmp}/stderr"
  local status="$?"
  set -e
  if [[ "${status}" -eq 0 ]]; then
    echo "expected failure: $*" >&2
    return 1
  fi
  grep -Fq -- "${expected_message}" "${test_tmp}/stderr"
}

expect_failure "Usage: output_def_file" "${DEF_FILE_GENERATOR}"
expect_failure "Could not open parameter file" \
  "${DEF_FILE_GENERATOR}" "${test_tmp}/missing.def" sample.dll \
  "@${test_tmp}/missing.params"

printf "'unterminated\n" >"${test_tmp}/malformed.params"
expect_failure "unterminated shell parameter quote" \
  "${DEF_FILE_GENERATOR}" "${test_tmp}/malformed.def" sample.dll \
  "@${test_tmp}/malformed.params"

mkdir "${test_tmp}/quoted inputs"
cat >"${test_tmp}/quoted inputs/symbols.c" <<'EOF'
int mutable_data = 1;
const int readonly_data = 2;
int exported_function(void) { return mutable_data + readonly_data; }
EOF

"${CLANG_CL}" /nologo /clang:--target=x86_64-pc-windows-msvc /c \
  "/Fo${test_tmp}/quoted inputs/symbols.obj" \
  "${test_tmp}/quoted inputs/symbols.c"
"${CLANG_CL}" /nologo /clang:--target=x86_64-pc-windows-msvc \
  /clang:-flto=thin /c \
  "/Fo${test_tmp}/quoted inputs/symbols.thinlto.obj" \
  "${test_tmp}/quoted inputs/symbols.c"
"${BIGOBJ_FIXTURE_WRITER}" "${test_tmp}/quoted inputs/symbols-big.s"
"${CLANG_CL}" /nologo /clang:--target=x86_64-pc-windows-msvc /c \
  "/Fo${test_tmp}/quoted inputs/symbols-big.obj" \
  "${test_tmp}/quoted inputs/symbols-big.s"

printf 'LIBRARY old.dll\nEXPORTS\n  ExistingData \t DATA\n  Existing\n' \
  >"${test_tmp}/quoted inputs/existing.DEF"
{
  printf '"%s"\n' "${test_tmp}/quoted inputs/symbols.obj"
  printf '"%s"\n' "${test_tmp}/quoted inputs/symbols.thinlto.obj"
  printf '"%s"\n' "${test_tmp}/quoted inputs/symbols-big.obj"
  printf '"%s"\n' "${test_tmp}/quoted inputs/existing.DEF"
} >"${test_tmp}/inputs.params"

"${DEF_FILE_GENERATOR}" "${test_tmp}/merged.def" sample.dll \
  "@${test_tmp}/inputs.params"

cat >"${test_tmp}/expected.def" <<'EOF'
LIBRARY sample.dll
EXPORTS 
	ExistingData 	 DATA
	mutable_data 	 DATA
	readonly_data 	 DATA
	Existing
	bigobj_function
	exported_function
EOF
diff -u "${test_tmp}/expected.def" "${test_tmp}/merged.def"

printf 'not an object\n' >"${test_tmp}/malformed.obj"
expect_failure "llvm-nm exited with status" \
  "${DEF_FILE_GENERATOR}" "${test_tmp}/rejected.def" sample.dll \
  "${test_tmp}/malformed.obj"

expect_failure "DEF_FILE_GENERATOR_ABI must be 'msvc' or 'gnu'" \
  env DEF_FILE_GENERATOR_ABI=itanium \
  "${DEF_FILE_GENERATOR}" "${test_tmp}/rejected.def" sample.dll \
  "${test_tmp}/quoted inputs/symbols.obj"

mkdir "${test_tmp}/mingw"
cat >"${test_tmp}/mingw/classes.cpp" <<'EOF'
struct Base {
  virtual ~Base();
  virtual int f() const;
  static int counter;
};
Base::~Base() {}
int Base::f() const { return counter; }
int Base::counter = 3;
extern const int table[3] = {1, 2, 3};
template <typename T> T twice(T t) { return t + t; }
template int twice<int>(int);
extern "C" int DllMain(void *, unsigned, void *) { return 1; }
static int local_helper() { return 2; }
int call_local() { return local_helper(); }
EOF
cat >"${test_tmp}/mingw/runtime.c" <<'EOF'
int common_var;
int imported_elsewhere(void) { return 0; }
void *__imp_imported_elsewhere = (void *)&imported_elsewhere;
__attribute__((weak)) int weak_function(void) { return 5; }
int DllMainCRTStartup(void *a, unsigned b, void *c) { return 1; }
EOF
"${CLANGXX}" --target=x86_64-w64-windows-gnu -fno-exceptions -c \
  -o "${test_tmp}/mingw/classes.o" "${test_tmp}/mingw/classes.cpp"
"${CLANGXX}" --target=x86_64-w64-windows-gnu -x c -fcommon -c \
  -o "${test_tmp}/mingw/runtime.o" "${test_tmp}/mingw/runtime.c"

DEF_FILE_GENERATOR_ABI=gnu "${DEF_FILE_GENERATOR}" "${test_tmp}/mingw.def" \
  libsample.dll "${test_tmp}/mingw/classes.o" "${test_tmp}/mingw/runtime.o"

cat >"${test_tmp}/expected_mingw.def" <<'EOF'
LIBRARY libsample.dll
EXPORTS 
	_ZN4Base7counterE 	 DATA
	_ZTI4Base 	 DATA
	_ZTS4Base 	 DATA
	_ZTV4Base 	 DATA
	common_var 	 DATA
	table 	 DATA
	_Z10call_localv
	_Z5twiceIiET_S0_
	_ZN4BaseD0Ev
	_ZN4BaseD1Ev
	_ZN4BaseD2Ev
	_ZNK4Base1fEv
EOF
diff -u "${test_tmp}/expected_mingw.def" "${test_tmp}/mingw.def"
