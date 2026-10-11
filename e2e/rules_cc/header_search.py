"""Execute the real Bazel command and compare -E -v with native Clang."""

import json
import os
from pathlib import Path
import subprocess
import sys


def reference(arguments, family, user):
    # Recover locations, not ordering, from the configured installation.
    # C/C++ include categories in the reference are owned entirely by Clang.
    result = []
    args = iter(arguments)
    for arg in args:
        arg = arg.removeprefix("/clang:")
        if arg in ("-target", "--target", "-isysroot", "-resource-dir"):
            result += [arg, next(args).removeprefix("/clang:")]
        elif arg.startswith(("--target=", "--sysroot=", "-resource-dir=", "-stdlib++-isystem", "/vctoolsdir", "/winsdkdir", "/winsdkversion")):
            result.append(arg)
        elif arg == "-Xclang":
            option = next(args).removeprefix("/clang:")
            if option == "-internal-isystem":
                assert next(args).removeprefix("/clang:") == "-Xclang"
                directory = next(args).removeprefix("/clang:")
                # Supplemental source-version sanitizer interfaces are the
                # one intentional addition beyond native driver discovery.
                assert directory.endswith("/compiler-rt/include"), directory
                result += ["-Xclang", option, "-Xclang", directory]
    if family in ("gnu", "musl"):
        result += ["--gcc-toolchain=/dev/null"]
    elif family == "darwin":
        result += ["-stdlib=libc++"]
    elif family == "none":
        result += ["-nostdlibinc"]
    result += ["/imsvc" + user] if family == "msvc" else ["-isystem", user]
    if family == "msvc":
        result = [arg if arg.startswith(("/imsvc", "/vctoolsdir", "/winsdk")) else "/clang:" + arg for arg in result]
    return result


def search(compiler, arguments, language, family):
    env = dict(os.environ)
    for name in ("CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJC_INCLUDE_PATH", "INCLUDE", "EXTERNAL_INCLUDE", "SDKROOT"):
        env.pop(name, None)
    tail = ["/E", "/clang:-v", "/TP" if language == "c++" else "/TC"] if family == "msvc" else ["-E", "-v", "-x", language]
    run = subprocess.run([compiler, *arguments, *tail, "-"], input="\n", capture_output=True, text=True, env=env)
    if run.returncode:
        raise AssertionError(run.stderr)
    paths = run.stderr.split("#include <...> search starts here:\n", 1)[1].split("End of search list.", 1)[0]
    return [line.strip() for line in paths.splitlines() if line.strip()]


def normalize_resources(paths, arguments):
    paths = [path.replace("\\", "/") for path in paths]
    resources = [arg.removeprefix("/clang:").split("=", 1)[1] for arg in arguments if arg.removeprefix("/clang:").startswith("-resource-dir=")]
    for resource in resources:
        paths = [path.replace(resource.replace("\\", "/") + "/", "$RESOURCE/") for path in paths]
    return paths


config = json.loads(Path(sys.argv[1]).read_text())
link_headers = [arg for arg in config["link_arguments"] if arg.removeprefix("/clang:").startswith(("--sysroot=", "-resource-dir="))]
assert not any("-stdlib++-isystem" in arg for arg in config["link_arguments"])
reports = {}
for language, command in config["commands"].items():
    args = command["arguments"]
    native = reference(args, config["family"], config["user"])
    if config["family"] in ("gnu", "musl", "mingw"):
        sysroots = [arg.split("=", 1)[1] for arg in args if arg.startswith("--sysroot=")]
        assert len(sysroots) == 1, sysroots
        sysroot = Path(sysroots[0])
        required = ["include/windows.h"] if config["family"] == "mingw" else ["include/linux/types.h", "usr/include/stdlib.h"]
        for header in required:
            assert (sysroot / header).is_file(), f"Missing native sysroot header: {sysroot / header}"
    actual_paths = search(command["compiler"], args, language, config["family"])
    native_paths = search(command["compiler"], native, language, config["family"])
    if actual_paths != native_paths:
        raise AssertionError(f"{language}:\nBazel: {actual_paths}\nDriver: {native_paths}\nArgs: {args}")
    reports[language] = {"bazel": actual_paths, "driver": native_paths, "arguments": args, "reference": native}
    # Configure/cgo consumers combine compile and link flags. Both resource
    # directories must contain headers, and neither order may lose the sysroot.
    for name, combined in (("compile_then_link", args + link_headers), ("link_then_compile", link_headers + args)):
        paths = search(command["compiler"], combined, language, config["family"])
        assert normalize_resources(paths, combined) == normalize_resources(actual_paths, args), (name, paths, actual_paths)
        reports[language][name] = paths
Path(sys.argv[2]).write_text(json.dumps(reports, indent=2) + "\n")
