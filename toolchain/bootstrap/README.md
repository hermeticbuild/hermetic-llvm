# Bootstrap toolchain

This package holds bazel toolchain definitions whose LLVM toolchain binaries are
compiled from source using the `prebuilt` bootstrap stage.

It is then used to compile user programs as long as
`//toolchain:bootstrap_stage=bootstrapped`
is in the configuration.
