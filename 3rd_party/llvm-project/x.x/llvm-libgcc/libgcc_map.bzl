# Step two of generating the version script of libgcc_s.so.1: libgcc.map, the
# script the linker applies, with exactly the symbols the library defines
# under the GCC_* versions of the selected GCC release.
#
# libgcc/Makefile.in builds it from libgcc.map.in and the objects that go
# into libgcc_s.so:
#
#   libgcc.map: libgcc.map.in $(objects)
#       { $(NM) -pg $(objects); echo %%; cat libgcc.map.in; } \
#         | $(AWK) -f mkmap-symver.awk > $@
#
# mkmap-symver.awk reads the nm output first (everything before the %% line)
# and keeps only the symbols of libgcc.map.in that the objects actually
# define, resolves the %inherit (version A extends version B) and %exclude
# lines into the parent relationships a version script expresses, drops the
# versions that end up empty, and closes with `local: *` so that nothing else
# is exported.
#
# Implementation: the same recipe, with the archives of libunwind and the
# compiler-rt builtins (taken from the CcInfo of the deps, so they are the
# very objects that get linked) as the objects and llvm-nm as nm. Because the
# awk takes its symbol list from nm, symbols compiler-rt lacks (__clrsb*,
# __register_frame_info*, ...) are simply absent, as they would be from a
# libgcc built without them, and version nodes left empty (GCC_4.7.0)
# disappear with them.
#
# One correction on top, the keep-last-entry pass. GCC's fragments list a few
# symbols under two versions, an older one kept for binary compatibility and
# the corrected one (config/i386/libgcc-glibc.ver: __divtc3 under GCC_4.0.0
# and GCC_4.3.0). A linker assigns a symbol to the first version that names
# it. libgcc's objects still get the corrected default because they also
# define the old version as a .symver alias, which claims the earlier entry;
# compiler-rt has no such aliases, so without the pass __divtc3 would come out
# as GCC_4.0.0. Keeping only the last entry of each symbol gives it its
# default version, matching GCC's library.

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

# The keep-last-entry pass. mkmap-symver.awk prints one version block after
# another, parents first, each symbol on its own "\tsymbol;" line. The file
# is read twice (hence "$1" "$1"): the first pass numbers the blocks and
# records the last block naming each symbol, the second pass prints the file
# again, skipping a symbol line whenever an earlier block is naming it.
_KEEP_LAST_ENTRY = """
awk '
    FNR == 1 { node = 0 }
    /^[^ \\t}].* \\{$/ { node++ }
    /^\\t[^*].*;$/ { if (NR == FNR) last[$0] = node; else if (last[$0] != node) next }
    NR != FNR { print }
' "$1" "$1"
"""

# The archives (or bare objects) of a dependency, the inputs nm inspects.
def _libraries(cc_info):
    files = []
    for linker_input in cc_info.linking_context.linker_inputs.to_list():
        for library in linker_input.libraries:
            archive = library.pic_static_library or library.static_library
            if archive:
                files.append(archive)
            else:
                files.extend(library.pic_objects or library.objects or [])
    return files

def _libgcc_map_impl(ctx):
    libraries = []
    for dep in ctx.attr.deps:
        libraries.extend(_libraries(dep[CcInfo]))
    output = ctx.actions.declare_file(ctx.label.name)

    # The libgcc.map recipe from libgcc/Makefile.in (SHLIB_NM_FLAGS is -pg:
    # POSIX output, global symbols only), then the keep-last-entry pass.
    ctx.actions.run_shell(
        inputs = [ctx.file.map_in, ctx.file.mkmap] + libraries,
        outputs = [output],
        tools = [ctx.file._nm],
        arguments = [
            ctx.file._nm.path,
            ctx.file.mkmap.path,
            ctx.file.map_in.path,
            output.path,
        ] + [library.path for library in libraries],
        command = """set -eu
nm="$1"
mkmap="$2"
map_in="$3"
out="$4"
shift 4
{ "$nm" -p -g "$@"; echo %%; cat "$map_in"; } | awk -f "$mkmap" > "$out.mkmap"
keep_last_entry() {""" + _KEEP_LAST_ENTRY + """}
keep_last_entry "$out.mkmap" > "$out"
rm -f "$out.mkmap"
""",
        mnemonic = "LibgccMap",
    )

    return [DefaultInfo(files = depset([output]))]

libgcc_map = rule(
    implementation = _libgcc_map_impl,
    doc = "Generates libgcc.map for libgcc_s.so.1 from GCC's libgcc.map.in and the symbols the deps define, as libgcc/Makefile.in does.",
    attrs = {
        # @gcc//:libgcc.map.in for the selected GCC release, the output of
        # //3rd_party/gcc/libgcc:libgcc_map_in.bzl (step one above).
        "map_in": attr.label(allow_single_file = True, mandatory = True),
        # GCC's libgcc/mkmap-symver.awk, from the same release.
        "mkmap": attr.label(allow_single_file = True, mandatory = True),
        # The libraries that make up libgcc_s.so.1; their symbols are the
        # ones the map may name.
        "deps": attr.label_list(providers = [CcInfo], mandatory = True),
        # The stage0 tool is a prebuilt file behind the alias, not a rule.
        "_nm": attr.label(
            default = "@llvm//tools:llvm-nm",
            allow_single_file = True,
            cfg = "exec",
        ),
    },
)
