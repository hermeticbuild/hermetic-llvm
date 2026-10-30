# C++ standard-library setting contract

Build `defaults`, `headers_only`, `libraries_only`, and `both` to exercise all
four combinations of `//config:nostdincxx` and `//config:nostdlibxx`:

```sh
bazel build --config=remote \
  //tests/cxxstdlib_settings:defaults \
  //tests/cxxstdlib_settings:headers_only \
  //tests/cxxstdlib_settings:libraries_only \
  //tests/cxxstdlib_settings:both
```

Each produces a target executable, an execution-platform executable, and a
`contract.json` report containing the selected compile/link arguments and
static/dynamic runtime providers. Analysis fails on inconsistent selection,
lost Linux unwind support, or leakage across the exec transition. Compilation
checks that C++ headers disappear only with `nostdincxx`, while an explicit
header/archive and the C runtime remain usable. Successful execution prints
`replacement runtime: 42`.

The same targets can be built from an external consumer as
`@llvm//tests/cxxstdlib_settings:<name>`. For Windows MSVC cross-builds, select
`@llvm//platforms:windows_x86_64_msvc` and use the documented Microsoft EULA and
CRT options. The probes can then be run under Wine on a supported executor.

This contract covers ordinary hosted C++ consumers, not freestanding targets.
