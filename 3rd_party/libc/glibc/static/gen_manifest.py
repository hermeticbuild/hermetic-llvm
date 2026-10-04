#!/usr/bin/env python3
"""Turn a reference glibc build into a Bazel manifest.

Usage: gen_manifest.py <arch> <src-dir> <build-dir> <make.log> <out-dir>

`make V=1` of a configured glibc tree prints every compile command.  This
script keeps the ones whose object ends up in the static archives a fully
static link needs (libc.a, libm.a) or in the static startup files (crt1.o,
rcrt1.o), rewrites each into a form that does not depend on where the build
ran, and writes

  <out-dir>/manifest.bzl      INCLUDES, FLAGS, FLAG_SETS, OBJECTS, ARCHIVES, CRT
  <out-dir>/gen/...           every file of the *build* tree those commands
                              read: configure/make output (config.h,
                              libc-modules.h, the gen-as-const headers, ...)
                              and the syscall stubs make pipes into the
                              assembler, materialized as .S files.

Paths in the manifest use three placeholders the Bazel rule substitutes:
  {src}  the glibc source tree      {gen}  <out-dir>/gen      {sub}  per object
"""

import os
import re
import shlex
import shutil
import subprocess
import sys

arch, SRC, BUILD, LOG, OUT = sys.argv[1:6]
SRC = os.path.realpath(SRC)
BUILD = os.path.realpath(BUILD)
AR = os.environ.get("AR", "llvm-ar")

# The log was written inside a container; map its paths onto ours.
LOG_BUILD = os.environ.get("LOG_BUILD", "/w/build-" + arch)
LOG_SRC = os.environ.get("LOG_SRC", "/w/glibc-2.44")

ARCHIVES = {"libc.a": "libc.a", "libm.a": "math/libm.a"}
# The startup files of a static link.  The toolchain's own are made for dynamic
# links and will not do: its crt1.o has no static-reloc.o (the stub of
# _dl_relocate_static_pie a non-PIE static link needs), and its crti.o/crtn.o
# are empty, while libc.a's __libc_start_main calls the _init/_fini they define.
CRT = {
    "crt1.o": ["csu/start.o", "csu/abi-note.o", "csu/init.o", "csu/static-reloc.o"],
    "rcrt1.o": ["csu/start.o", "csu/abi-note.o", "csu/init.o"],
    "crti.o": ["csu/crti.o"],
    "crtn.o": ["csu/crtn.o"],
}


def members(path):
    out = subprocess.run([AR, "t", os.path.join(BUILD, path)], check=True,
                         capture_output=True, text=True).stdout.split()
    return out


# object basename -> must be unique per archive for `ar t` to identify it.
wanted = {}  # build-relative object path -> set(archive)
by_base = {}
for name, path in ARCHIVES.items():
    for m in members(path):
        by_base.setdefault(m, set()).add(name)
for objs in CRT.values():
    for o in objs:
        wanted.setdefault(o, set())

# -target: a cross reference build names its target in CC; the Bazel toolchain
# supplies its own.
# Build-tree files every compile #includes but no *static* compile uses, written
# out as one-line stubs.  Both are tables for shared-library symbol versioning
# (shlib-compat.h): without SHARED, SHLIB_COMPAT() is the constant 0 and
# compat_symbol() expands to nothing.  They were 43% of the generated data.
# Verified, not assumed: with the stubs in place every object of libc.a and
# libm.a and every startup file came out byte-identical, on both architectures.
# Re-check when GLIBC_STATIC_VERSION changes (build, stub, compare sha256).
STUBBED = {
    "first-versions.h": "/* Stub: shared-library symbol versions; unused in a static build. */\n",
    "abi-versions.h": "/* Stub: shared-library symbol versions; unused in a static build. */\n",
}

DROP_WITH_ARG = {"-MF", "-MT", "-o", "-target"}
DROP = {"-MD", "-MP", "-c", "-g"}


def rel_build(p):
    return os.path.relpath(p, LOG_BUILD)


def rewrite_path(p, sub):
    """A path argument as the log spells it -> placeholder form."""
    if p.startswith(LOG_BUILD + "/") or p == LOG_BUILD:
        r = os.path.normpath(os.path.relpath(p, LOG_BUILD))
        return "{gen}" if r == "." else "{gen}/" + r
    if p.startswith(LOG_SRC + "/") or p == LOG_SRC:
        r = os.path.normpath(os.path.relpath(p, LOG_SRC))
        return "{src}" if r == "." else "{src}/" + r
    if os.path.isabs(p):
        raise ValueError("absolute path outside both trees: " + p)
    r = os.path.normpath(os.path.join(sub, p))
    if r.startswith(".."):
        raise ValueError("path escapes the source tree: %s (in %s)" % (p, sub))
    return "{src}" if r == "." else "{src}/" + r


objects = {}  # obj -> (src placeholder path, sub, flags tuple)
stubs = {}    # gen-relative .S path -> text

def logical_lines(path):
    """make prints a recipe with its backslash-newlines; join them."""
    acc = ""
    for raw in open(path, errors="replace"):
        raw = raw.rstrip("\n")
        if raw.endswith("\\"):
            acc += raw[:-1] + "\n"
            continue
        yield acc + raw
        acc = ""


for line in logical_lines(LOG):
    last = line.rsplit("\n", 1)[-1]
    m = re.search(r" -o (" + re.escape(LOG_BUILD) + r"/\S+\.o)(?: |$)", last)
    if not m or " -c" not in last:
        continue
    obj = rel_build(m.group(1))
    base = os.path.basename(obj)
    in_archive = by_base.get(base, set())
    if obj not in wanted and not in_archive:
        continue
    piped = None
    if "| clang " in line:
        piped, _, rest = line.rpartition("| clang ")
        argv = shlex.split(rest)
    else:
        # Not anchored: with -j, another job's unterminated output can be
        # glued to the front of the line ("dl-cache.cclang dl-addr-obj.c ...").
        k = last.find("clang ")
        if k < 0:
            continue
        argv = shlex.split(last[k + len("clang "):])

    # The sub-directory make ran in: the first -I<build>/<sub>.
    sub = None
    for a in argv:
        if a.startswith("-I" + LOG_BUILD + "/"):
            sub = a[len("-I" + LOG_BUILD + "/"):].strip("/")
            break
    if sub is None:
        raise ValueError("no sub-directory in: " + line[:200])

    flags, src, i = [], None, 0
    while i < len(argv):
        a = argv[i]
        if a in DROP_WITH_ARG:
            i += 2
            continue
        if a in DROP:
            i += 1
            continue
        if a in ("-include", "-x"):
            nxt = argv[i + 1]
            flags += [a, rewrite_path(nxt, sub) if a == "-include" else nxt]
            i += 2
            continue
        if a == "-":
            i += 1
            continue
        if a.startswith("-I"):
            flags.append("-I" + rewrite_path(a[2:], sub))
        elif a.startswith("-"):
            flags.append(a)
        else:
            if src is not None:
                raise ValueError("two sources in: " + line[:200])
            src = rewrite_path(a, sub)
        i += 1

    if piped is not None:
        # `(echo ...; echo ...) | clang -x assembler-with-cpp -`: run the
        # echoes, keep the text.
        text = subprocess.run(["bash", "-c", piped.strip()], check=True,
                              capture_output=True, text=True).stdout
        rel = "stubs/" + obj[:-2] + ".S"
        stubs[rel] = text
        src = "{gen}/" + rel
        if "-x" in flags:
            k = flags.index("-x")
            del flags[k:k + 2]
    if src is None:
        raise ValueError("no source in: " + line[:200])

    flags = tuple(f.replace("{src}/" + sub + "/", "{src}/{sub}/")
                   .replace("{gen}/" + sub + "/", "{gen}/{sub}/")
                  if not f.endswith("/" + sub) else
                  f[:-len(sub)] + "{sub}" for f in flags)
    objects[obj] = (src, sub, flags)

# Which archive each compiled object belongs to.  Member names are basenames;
# a basename built in two sub-directories is resolved by asking the build tree
# which of them the archive's copy is byte-identical to.
archive_objs = {n: [] for n in ARCHIVES}
for name, path in ARCHIVES.items():
    tmp = os.path.join(OUT, ".x-" + name)
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    subprocess.run([AR, "x", os.path.join(BUILD, path)], cwd=tmp, check=True)
    cands = {}
    for o in objects:
        cands.setdefault(os.path.basename(o), []).append(o)
    for mname in members(path):
        c = cands.get(mname, [])
        if len(c) > 1:
            want = open(os.path.join(tmp, mname), "rb").read()
            c = [o for o in c if open(os.path.join(BUILD, o), "rb").read() == want]
        if len(c) != 1:
            raise ValueError("%s: member %s has %d candidates" % (name, mname, len(c)))
        archive_objs[name].append(c[0])
    shutil.rmtree(tmp)

used = set(o for v in archive_objs.values() for o in v)
for objs in CRT.values():
    used.update(objs)
missing = [o for o in used if o not in objects]
if missing:
    raise ValueError("no compile command found for: " + ", ".join(missing[:10]))
objects = {o: v for o, v in objects.items() if o in used}
stubs = {k: v for k, v in stubs.items() if k[len("stubs/"):-2] + ".o" in used}

# Generated files: everything under the build tree the dep files mention.
gen_files = set()
for o in objects:
    for ext in (".o.d",):
        d = os.path.join(BUILD, o[:-2] + ext)
        if not os.path.exists(d):
            continue
        for tok in open(d).read().replace("\\\n", " ").split():
            tok = tok.rstrip(":")
            if tok.startswith("$(common-objpfx)"):
                tok = tok[len("$(common-objpfx)"):]
            elif tok.startswith(LOG_BUILD + "/"):
                tok = tok[len(LOG_BUILD) + 1:]
            else:
                continue
            if tok.endswith((".o", ".os")):
                continue
            gen_files.add(os.path.normpath(tok))
for src, _, flags in objects.values():
    for s in (src,) + flags:
        if "{gen}/" in s and "{sub}" not in s and not s.startswith("-I"):
            p = s.split("{gen}/", 1)[1]
            if not p.startswith("stubs/"):
                gen_files.add(p)

gen = os.path.join(OUT, "gen")
shutil.rmtree(gen, ignore_errors=True)
for f in sorted(gen_files):
    s = os.path.join(BUILD, f)
    if not os.path.isfile(s):
        continue
    os.makedirs(os.path.dirname(os.path.join(gen, f)), exist_ok=True)
    if f in STUBBED:
        open(os.path.join(gen, f), "w").write(STUBBED[f])
    elif f.endswith(".S"):
        # Preprocessor output (errlist-data-aux.S): drop the line markers,
        # which spell the directory the reference build ran in.
        text = "".join(l for l in open(s) if not re.match(r'# \d+ "', l))
        open(os.path.join(gen, f), "w").write(text)
    else:
        shutil.copyfile(s, os.path.join(gen, f))
for rel, text in stubs.items():
    os.makedirs(os.path.dirname(os.path.join(gen, rel)), exist_ok=True)
    open(os.path.join(gen, rel), "w").write(text)

# Every flag set carries the same ~45 sysdeps -I directories; name that block
# once.  It is the run from the first -I to the last in the commonest set.
def include_block(fs):
    idx = [i for i, x in enumerate(fs) if x.startswith("-I")]
    return tuple(fs[idx[0]:idx[-1] + 1]) if idx else ()


counts = {}
for _, _, fl in objects.values():
    b = include_block(fl)
    counts[b] = counts.get(b, 0) + 1
INCLUDES = max(counts, key=counts.get)


def fold(fs):
    n = len(INCLUDES)
    for i in range(len(fs) - n + 1):
        if tuple(fs[i:i + n]) == INCLUDES:
            return tuple(fs[:i]) + ("@INCLUDES",) + tuple(fs[i + n:])
    return fs


objects = {o: (s_, sub, fold(fl)) for o, (s_, sub, fl) in objects.items()}

flag_sets, index = [], {}
rows = []
for o in sorted(objects):
    src, sub, flags = objects[o]
    if flags not in index:
        index[flags] = len(flag_sets)
        flag_sets.append(flags)
    rows.append((o, src, sub, index[flags]))

with open(os.path.join(OUT, "manifest.bzl"), "w") as f:
    f.write('"""glibc static objects for %s.  Generated by gen_manifest.py; do not edit."""\n\n' % arch)
    f.write("# What \"@INCLUDES\" in a flag set stands for.\nINCLUDES = [\n")
    for x in INCLUDES:
        f.write('    "%s",\n' % x)
    f.write("]\n\n")
    # The few hundred flag sets are built from the same few dozen strings, so
    # each string is written once and a flag set is a list of indexes into
    # FLAGS.  Order within a set is preserved exactly -- it matters for
    # -include, and for -D against -U.
    flags, flag_index = [], {}
    for fs in flag_sets:
        for x in fs:
            if x not in flag_index:
                flag_index[x] = len(flags)
                flags.append(x)
    f.write("FLAGS = [\n")
    for x in flags:
        f.write('    "%s",\n' % x.replace("\\", "\\\\").replace('"', '\\"'))
    f.write("]\n\n# Each entry: indexes into FLAGS.\n")
    f.write("FLAG_SETS = [\n")
    for fs in flag_sets:
        f.write("    [%s],\n" % ", ".join(str(flag_index[x]) for x in fs))
    f.write("]\n\n# (object, source, sub-directory, index into FLAG_SETS)\nOBJECTS = [\n")
    for r in rows:
        f.write('    ("%s", "%s", "%s", %d),\n' % r)
    f.write("]\n\nARCHIVES = {\n")
    for n in ARCHIVES:
        f.write('    "%s": [\n' % n)
        for o in archive_objs[n]:
            f.write('        "%s",\n' % o)
        f.write("    ],\n")
    f.write("}\n\nCRT = {\n")
    for n, objs in CRT.items():
        f.write('    "%s": [%s],\n' % (n, ", ".join('"%s"' % o for o in objs)))
    f.write("}\n")

print("%s: %d objects, %d flag sets, %d generated files, %d stubs" %
      (arch, len(rows), len(flag_sets), len(gen_files), len(stubs)))
