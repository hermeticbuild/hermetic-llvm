"""Checks a decompressed compact Bazel execution log read from stdin.

Fails if any spawn other than an FDO training action took its result from a
cache. Prints a Markdown summary, including the digests of the merged FDO
profiles.

The format is a stream of length-delimited ExecLogEntry messages, see
https://github.com/bazelbuild/bazel/blob/9.1.1/src/main/protobuf/spawn.proto.
"""

import sys

TRAINING_MNEMONICS = {"LLVMFDOProfileCompile", "LLVMFDOProfileLink"}

# ExecLogEntry field numbers.
ENTRY_ID = 1
ENTRY_FILE = 3
ENTRY_SPAWN = 7
FILE_PATH = 1
FILE_DIGEST = 2
DIGEST_HASH = 1
SPAWN_OUTPUTS = 6
SPAWN_MNEMONIC = 8
SPAWN_RUNNER = 11
SPAWN_CACHE_HIT = 12
OUTPUT_ID = 5


def varint(buf, pos):
    result = shift = 0
    while True:
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, pos
        shift += 7


def fields(buf):
    pos = 0
    while pos < len(buf):
        key, pos = varint(buf, pos)
        number, wire_type = key >> 3, key & 7
        if wire_type == 0:
            value, pos = varint(buf, pos)
        elif wire_type == 1:
            value, pos = buf[pos:pos + 8], pos + 8
        elif wire_type == 2:
            length, pos = varint(buf, pos)
            value, pos = buf[pos:pos + length], pos + length
        elif wire_type == 5:
            value, pos = buf[pos:pos + 4], pos + 4
        else:
            raise ValueError(f"unsupported wire type {wire_type}")
        yield number, value


def entries(stream):
    while True:
        length = shift = 0
        while True:
            b = stream.read(1)
            if not b:
                if shift:
                    raise ValueError("truncated execution log")
                return
            length |= (b[0] & 0x7F) << shift
            if not b[0] & 0x80:
                break
            shift += 7
        data = stream.read(length)
        if len(data) != length:
            raise ValueError("truncated execution log")
        yield memoryview(data)


def main():
    files = {}
    spawns = 0
    disallowed = []
    training = {}
    profdata = []
    for entry in entries(sys.stdin.buffer):
        entry_id = 0
        for number, value in fields(entry):
            if number == ENTRY_ID:
                entry_id = value
            elif number == ENTRY_FILE:
                path = digest = ""
                for n, v in fields(value):
                    if n == FILE_PATH:
                        path = bytes(v).decode()
                    elif n == FILE_DIGEST:
                        for dn, dv in fields(v):
                            if dn == DIGEST_HASH:
                                digest = bytes(dv).decode()
                if path.endswith(".profdata"):
                    files[entry_id] = (path, digest)
            elif number == ENTRY_SPAWN:
                spawns += 1
                mnemonic = runner = ""
                cache_hit = False
                outputs = []
                for n, v in fields(value):
                    if n == SPAWN_MNEMONIC:
                        mnemonic = bytes(v).decode()
                    elif n == SPAWN_RUNNER:
                        runner = bytes(v).decode()
                    elif n == SPAWN_CACHE_HIT:
                        cache_hit = bool(v)
                    elif n == SPAWN_OUTPUTS:
                        for on, ov in fields(v):
                            if on == OUTPUT_ID:
                                outputs.append(ov)
                if mnemonic in TRAINING_MNEMONICS:
                    hits, total = training.get(mnemonic, (0, 0))
                    training[mnemonic] = (hits + cache_hit, total + 1)
                elif cache_hit:
                    disallowed.append(f"{mnemonic} ({runner})")
                if mnemonic == "LLVMFDOProfileMerge":
                    profdata.extend(files[o] for o in outputs if o in files)

    print(f"- {spawns} spawns in the execution log")
    for mnemonic, (hits, total) in sorted(training.items()):
        print(f"- {mnemonic}: {hits} of {total} reused the results of the release build")
    for path, digest in sorted(profdata):
        print(f"- `{path}`: `{digest[:12]}`")
    for spawn in disallowed[:20]:
        print(f"::error::Spawn took its result from a cache: {spawn}", file=sys.stderr)
    if disallowed:
        print(f"- ❌ {len(disallowed)} other spawns took their results from a cache")
        sys.exit(1)
    print("- ✅ no other spawn took its result from a cache")


if __name__ == "__main__":
    main()
