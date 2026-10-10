"""Compare actual search paths with Clang, preserving historical musl flags."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def reference(arguments, family, user, root, language):
    # Give the unmodified driver a synthetic native installation. Map its C
    # slots back to the independent component paths; no production copy action
    # or sysroot layout is involved. C++ and builtin paths are the real inputs.
    result = []
    components = []
    supplemental = []
    mapped = {}
    musl_paths = []
    args = iter(arguments)
    for arg in args:
        arg = arg.removeprefix("/clang:")
        if arg in ("-target", "--target", "-isysroot", "-resource-dir"):
            result += [arg, next(args).removeprefix("/clang:")]
        elif arg.startswith(("--target=", "-resource-dir=", "-stdlib++-isystem")):
            assert family != "musl" or not arg.startswith("-stdlib++-isystem"), arg
            result.append(arg)
        elif arg == "-isystem" and family == "musl":
            directory = next(args)
            if directory != user:
                musl_paths.append(directory)
        elif arg in ("-Xclang", "-Xpreprocessor"):
            assert family != "musl" or arg != "-Xpreprocessor", arg
            option = next(args).removeprefix("/clang:")
            if option in ("-internal-isystem", "-internal-externc-isystem"):
                assert next(args).removeprefix("/clang:") == arg
                directory = next(args).removeprefix("/clang:")
                assert Path(directory).is_dir(), directory
                if directory.endswith("/compiler-rt/include"):
                    supplemental += ["-Xclang", option, "-Xclang", directory]
                else:
                    assert family != "musl", (option, directory)
                    if family == "gnu":
                        assert option == "-internal-externc-isystem"
                    components.append(directory)

    def slot(relative, directories):
        path = root / relative
        path.mkdir(parents=True, exist_ok=True)
        mapped[str(path)] = directories

    if family == "musl":
        # Preserve the baseline -isystem categories and relative order. This
        # explicitly does not claim native user-system-header precedence.
        assert len(musl_paths) == (4 if language == "c++" else 2), musl_paths
        assert (Path(musl_paths[-2]) / "linux/types.h").is_file()
        assert (Path(musl_paths[-1]) / "stdlib.h").is_file()
        result += ["-nostdlibinc"]
        for directory in musl_paths:
            result += ["-isystem", directory]
    elif family == "gnu":
        assert len(components) == 2, components
        assert (Path(components[0]) / "linux/types.h").is_file()
        assert (Path(components[1]) / "stdlib.h").is_file()
        slot("include", components[:1])
        slot("usr/include", components[1:])
        result += ["--sysroot=" + str(root), "--gcc-toolchain=/dev/null"]
    elif family == "mingw":
        assert len(components) == 4, components
        assert any((Path(path) / "windows.h").is_file() for path in components)
        slot("include", components)
        result += ["--sysroot=" + str(root)]
    elif family == "msvc":
        assert len(components) == 6, components
        slot("vc/include", components[:2])
        for name, directory in zip(("ucrt", "shared", "um", "winrt"), components[2:]):
            slot("sdk/Include/10.0.0/" + name, [directory])
        result += ["/vctoolsdir" + str(root / "vc"), "/winsdkdir" + str(root / "sdk"), "/winsdkversion10.0.0"]
    elif family == "darwin":
        result += ["-stdlib=libc++"]
    elif family == "none":
        result += ["-nostdlibinc"]
    result += supplemental
    result += ["/imsvc" + user] if family == "msvc" else ["-isystem", user]
    if family == "msvc":
        result = [arg if arg.startswith(("/imsvc", "/vctoolsdir", "/winsdk")) else "/clang:" + arg for arg in result]
    return result, mapped


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
    actual_paths = search(command["compiler"], args, language, config["family"])
    with tempfile.TemporaryDirectory() as temporary:
        native, mapped = reference(args, config["family"], config["user"], Path(temporary), language)
        native_paths = search(command["compiler"], native, language, config["family"])
        native_paths = [component for path in native_paths for component in mapped.get(path, [path])]
    if actual_paths != native_paths:
        raise AssertionError(f"{language}:\nBazel: {actual_paths}\nDriver: {native_paths}\nArgs: {args}")
    reports[language] = {
        "bazel": actual_paths,
        "driver": native_paths,
        "arguments": args,
        "reference": native,
        "policy": "historical-musl" if config["family"] == "musl" else "native-driver",
    }
    # Configure/cgo consumers combine compile and link flags. Both resource
    # directories must contain headers, and neither order may lose the sysroot.
    for name, combined in (("compile_then_link", args + link_headers), ("link_then_compile", link_headers + args)):
        paths = search(command["compiler"], combined, language, config["family"])
        assert normalize_resources(paths, combined) == normalize_resources(actual_paths, args), (name, paths, actual_paths)
        reports[language][name] = paths
Path(sys.argv[2]).write_text(json.dumps(reports, indent=2) + "\n")
