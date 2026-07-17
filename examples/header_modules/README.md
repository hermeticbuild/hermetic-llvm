# Clang header modules

This example enables Clang header modules for a package: each library's
headers are compiled once into a Clang module (a `.pcm` file), and dependents
import the module instead of re-parsing the headers textually. Requires
Bazel 9.3.0 or later. The example also enables `layering_check`, which turns
including a header of an undeclared dependency into an error naming the
missing dependency.

```starlark
package(features = [
    "header_modules",
    "use_header_modules",
    "layering_check",
])
```

## The C++ standard library

The toolchain compiles the public C++ standard library headers once into a
Clang module and adds it as a dependency of every C++ target, so they are
imported everywhere instead of being re-parsed into every module that
includes them, which is both faster and avoids known Clang issues with
merging many textually absorbed copies of the standard library declarations.
Other system headers are declared as textual headers in the toolchain's
module map, so they can be included without a compiled module.

## Module codegen

Optionally, enable `header_module_codegen` and
`header_modules_codegen_functions` (per target or globally) to additionally
compile each module into an object file that provides the code for inline
functions and template instantiations triggered inside the module, which
importing translation units then no longer emit themselves.

## Caveats

- Compiled modules are shared across a configuration: targets whose language
  options diverge from the configuration-wide defaults (e.g. via per-target
  `copts` such as `-std=` or `-fno-exceptions`) can't load them and need to
  opt out with `features = ["-use_header_modules"]`.
