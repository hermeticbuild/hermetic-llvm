"""Cross-target driver contract, using synthetic SDKs and real preprocessing.

Run directly with a Clang path to compare LLVM releases; no target executable
or host SDK is needed. Real Bazel header precedence is checked separately by
header_precedence in this package.
"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


TARGETS = {
    "gnu": ["x86_64-linux-gnu", "aarch64-linux-gnu", "riscv64-linux-gnu", "s390x-linux-gnu", "armv7-linux-gnueabihf"],
    "musl": ["x86_64-linux-musl", "aarch64-linux-musl", "riscv64-linux-musl", "s390x-linux-musl", "armv7-linux-musleabihf"],
    "darwin": ["x86_64-apple-macosx11.0", "arm64-apple-macosx11.0"],
    "mingw": ["x86_64-w64-windows-gnu", "aarch64-w64-windows-gnu"],
    "msvc": ["x86_64-pc-windows-msvc", "aarch64-pc-windows-msvc"],
    "none": ["bpfeb", "bpfel", "wasm32-unknown-unknown", "wasm64-unknown-unknown"],
}

CLANG = os.path.abspath(sys.argv.pop(1) if len(sys.argv) > 1 else os.environ["CLANG"])


class HeaderOrderTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.directories = {
            "user": "user",
            "cxx": "cxx",
            "abi": "abi",
            "builtin": "resource/include",
            "cuda": "resource/include/cuda_wrappers",
            "kernel": "sysroot/include",
            "libc": "sysroot/usr/include",
            "darwin_cxx": "sysroot/usr/include/c++/v1",
            "vc": "vc/include",
            "ucrt": "sdk/Include/10.0.0/ucrt",
            "shared": "sdk/Include/10.0.0/shared",
            "um": "sdk/Include/10.0.0/um",
            "winrt": "sdk/Include/10.0.0/winrt",
        }
        for name, path in self.directories.items():
            directory = self.root / path
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "header_order.h").write_text(
                f"{name}\n#if __has_include_next(<header_order.h>)\n"
                "#include_next <header_order.h>\n#endif\n"
            )

    def arguments(self, family, target, language):
        args = [f"--target={target}", f"-resource-dir={self.root}/resource"]
        # Deliberately supply toolchain paths before user paths. Their semantic
        # categories, not argv position, must determine header precedence.
        cxx = [f"-stdlib++-isystem{self.root}/{path}" for path in ("cxx", "abi")]
        expected = ["user"]
        if family == "none":
            args += ["-nostdlibinc"]
            expected += ["builtin"]
        elif family == "darwin":
            args += ["-isysroot", str(self.root / "sysroot"), "-stdlib=libc++"]
            expected += (["darwin_cxx"] if language == "c++" else []) + ["builtin", "libc"]
        elif family == "msvc":
            args += [f"/vctoolsdir{self.root}/vc", f"/winsdkdir{self.root}/sdk", "/winsdkversion10.0.0"]
            args += cxx if language == "c++" else []
            # /imsvc has a different native position from -isystem.
            expected = (["cxx", "abi"] if language == "c++" else []) + ["builtin", "user", "vc", "ucrt", "shared", "um", "winrt"]
        else:
            args += [f"--sysroot={self.root}/sysroot"]
            if family != "mingw":
                args += ["--gcc-toolchain=/dev/null"]
            args += cxx if language == "c++" else []
            expected += ["cxx", "abi"] if language == "c++" else []
            expected += {
                "gnu": ["builtin", "kernel", "libc"],
                "musl": ["kernel", "libc", "builtin"],
                "mingw": ["builtin", "kernel"],
            }[family]
        if family == "msvc":
            args += [f"/imsvc{self.root}/user"]
        else:
            args += ["-isystem", str(self.root / "user")]
        return args, expected

    def preprocess(self, args, language, cl=False):
        args = [*args, "-E", "-P", "-v"]
        if cl:
            args = ["--driver-mode=cl", *[
                arg if arg.startswith(("/imsvc", "/vctoolsdir", "/winsdk")) else "/clang:" + arg
                for arg in args
            ], "/TP" if language == "c++" else "/TC"]
        else:
            args += ["-x", language]
        env = dict(os.environ)
        for key in ("CPATH", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJC_INCLUDE_PATH", "SDKROOT"):
            env.pop(key, None)
        # Explicit SDK flags must suppress these ambient Windows paths.
        env["INCLUDE"] = env["EXTERNAL_INCLUDE"] = str(self.root / "host-poison")
        (self.root / "host-poison").mkdir(exist_ok=True)
        result = subprocess.run(
            [CLANG, "--no-default-config", *args, "-"],
            input="#include <header_order.h>\n", text=True, capture_output=True, env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        search = result.stderr.split("#include <...> search starts here:\n", 1)[1].split("End of search list.", 1)[0]
        for path in search.splitlines():
            directory = Path(path.strip().removesuffix(" (framework directory)"))
            self.assertTrue(directory.is_relative_to(self.root), result.stderr)
            self.assertNotIn("host-poison", path, result.stderr)
        return result.stdout.split()

    def test_native_order_and_include_next(self):
        for family, targets in TARGETS.items():
            for target in targets:
                for language in ("c", "c++"):
                    with self.subTest(target=target, language=language):
                        args, expected = self.arguments(family, target, language)
                        self.assertEqual(self.preprocess(args, language, family == "msvc"), expected)

    def test_builtin_and_cxx_opt_outs(self):
        for family, targets in TARGETS.items():
            for flag, removed in (("-nobuiltininc", {"builtin"}), ("-nostdinc++", {"cxx", "abi", "darwin_cxx"})):
                with self.subTest(family=family, flag=flag):
                    args, expected = self.arguments(family, targets[0], "c++")
                    self.assertEqual(self.preprocess([*args, flag], "c++", family == "msvc"), [x for x in expected if x not in removed])

    def test_cuda_wrappers_precede_cxx(self):
        args, expected = self.arguments("gnu", TARGETS["gnu"][0], "c++")
        # -nocudainc avoids requiring a toolkit, but preserves Clang's builtin
        # cuda_wrappers. The real PR reproducer also compiles device code.
        args += ["-nocudainc", "-nocudalib", "--cuda-host-only"]
        self.assertEqual(self.preprocess(args, "cuda"), ["user", "cuda", *expected[1:]])


if __name__ == "__main__":
    unittest.main()
