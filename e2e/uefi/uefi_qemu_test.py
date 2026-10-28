import json
import os
import shutil
import subprocess
import sys
import tempfile

from python.runfiles import runfiles


BOOT_MARKER = "UEFI_BOOT_OK"
_RUNFILES = runfiles.Create()


def rlocation(path):
    resolved = _RUNFILES.Rlocation(path)
    if resolved:
        return resolved
    if os.path.exists(path):
        return path
    raise FileNotFoundError(path)


def main():
    with open(rlocation(sys.argv[1]), encoding="utf-8") as config_file:
        config = json.load(config_file)

    if config["system_target"] != "x86_64-softmmu":
        raise RuntimeError(
            "UEFI test requires x86_64-softmmu, got {}".format(
                config["system_target"]
            )
        )

    qemu_system = rlocation(config["qemu_system"])
    system_data_dir = rlocation(config["system_data_anchor"])
    firmware = os.path.join(system_data_dir, "edk2-x86_64-code.fd")
    if not os.path.isfile(firmware):
        raise FileNotFoundError("QEMU UEFI firmware not found: {}".format(firmware))

    tmpdir = os.environ.get("TEST_TMPDIR") or tempfile.mkdtemp(prefix="uefi-qemu-")
    boot_dir = os.path.join(tmpdir, "esp", "EFI", "BOOT")
    os.makedirs(boot_dir, exist_ok=True)
    shutil.copyfile(
        rlocation(config["application"]),
        os.path.join(boot_dir, "BOOTX64.EFI"),
    )

    command = [
        qemu_system,
        "-L",
        system_data_dir,
        "-machine",
        config["machine"],
        "-accel",
        "tcg",
        "-display",
        "none",
        "-monitor",
        "none",
        "-serial",
        "none",
        "-no-reboot",
        "-drive",
        "if=pflash,format=raw,readonly=on,file={}".format(firmware),
        "-drive",
        "format=raw,file=fat:rw:{}".format(os.path.join(tmpdir, "esp")),
        "-debugcon",
        "stdio",
        "-global",
        "isa-debugcon.iobase=0xe9",
        "-device",
        "isa-debug-exit,iobase=0xf4,iosize=0x01",
    ]
    process = subprocess.Popen(
        command,
        env={**os.environ, "TMPDIR": tmpdir},
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=30)
    except subprocess.TimeoutExpired:
        process.kill()
        stdout, stderr = process.communicate()
        sys.stderr.write(stdout)
        sys.stderr.write(stderr)
        raise RuntimeError("QEMU did not exit after the UEFI boot timeout")

    if BOOT_MARKER not in stdout:
        sys.stderr.write(stdout)
        sys.stderr.write(stderr)
        raise RuntimeError("UEFI application did not emit its boot marker")
    if process.returncode != 67:
        sys.stderr.write(stdout)
        sys.stderr.write(stderr)
        raise RuntimeError("unexpected QEMU exit code {}".format(process.returncode))


if __name__ == "__main__":
    main()
