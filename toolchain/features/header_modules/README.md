# Clang header modules

Header modules let Clang reuse parsed dependency headers across source files. This can speed up incremental builds, especially when many files include libc++ or other large libraries. The first build pays the cost of compiling the modules.

## Enable modules

Use Bazel 9.3 or later and enable module consumption for your build.

```sh
bazel build --features=use_header_modules //:app
```

The toolchain supplies modules for libc++ and, on x86_64, Clang's intrinsics headers automatically. Other libraries must opt in before their headers can be reused as modules. Add `header_modules` to your library's `features` to do this.

```starlark
cc_library(
    name = "my_library",
    hdrs = ["my_library.h"],
    features = ["header_modules"],
)
```

Only opt in libraries whose headers compile on their own. Keep this per target instead of enabling `header_modules` globally. Libraries can consume dependency modules while keeping their own headers textual.

## Compatibility

- Windows MSVC targets cannot use compiled modules, since module support is not implemented for clang-cl. MinGW targets support them.
- A target's language options must match those used to compile its dependency modules. Opt out targets with differing `-std=` or exception settings.
- Protobuf 33.4's generated well-known-type modules fail with conflicting definitions. This is an unresolved compatibility issue. Disable modules for affected builds.

To opt out a target, set `features = ["-use_header_modules"]`. To disable modules for the whole build, pass `--features=-use_header_modules`.

## Module code generation

`header_modules_codegen_functions` and `header_modules_codegen_debuginfo` optionally put generated code or debug information into module object files. If this causes shared-library link errors, disable these features.
