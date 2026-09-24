/* Redirect one Clang CUDA wrapper payload relocation; no libelf dependency.
 * Input: little-endian ELF64 ET_REL, x86-64 or AArch64, empty fatbin
 * payload. Output: original code/data plus one undefined hidden symbol and
 * relocation. Build: cc -std=c11 -O2 -Wall -Wextra -Wpedantic cuda_redirect.c
 * -o cuda-redirect
 */
#define _POSIX_C_SOURCE 200809L
#include <elf.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct {
  uint32_t name, type, link, info;
  uint64_t flags, offset, size, align, entsize;
} Section;
typedef struct {
  uint32_t name;
  uint8_t info, other;
  uint16_t section;
  uint64_t value, size;
} Symbol;
typedef struct {
  uint64_t offset, size;
} Range;
typedef struct {
  unsigned char *data;
  size_t size;
  uint64_t shoff, nsyms;
  uint16_t machine, count, shstr, symtab, strtab;
  Section *sections;
} Elf;

static void require(bool ok, const char *message) {
  if (!ok) {
    fprintf(stderr, "reject: %s\n", message);
    exit(EXIT_FAILURE);
  }
}
static void syserr(const char *message) {
  perror(message);
  exit(EXIT_FAILURE);
}
static void *allocate(size_t size) {
  void *p = malloc(size ? size : 1);
  if (!p)
    syserr("malloc");
  return p;
}
/* Decode explicitly: no alignment, aliasing or build-machine endian
 * assumptions. */
static uint64_t get(const unsigned char *p, unsigned n) {
  uint64_t value = 0;
  for (unsigned i = 0; i < n; ++i)
    value |= (uint64_t)p[i] << (8 * i);
  return value;
}
static void put(unsigned char *p, unsigned n, uint64_t value) {
  for (unsigned i = 0; i < n; ++i)
    p[i] = (unsigned char)(value >> (8 * i));
}
static uint64_t add(uint64_t a, uint64_t b) {
  require(b <= UINT64_MAX - a, "integer overflow");
  return a + b;
}
static size_t host_size(uint64_t n) {
  require(n <= SIZE_MAX, "object too large for this process");
  return (size_t)n;
}
static const unsigned char *span(const Elf *e, uint64_t off, uint64_t size) {
  require(off <= e->size && size <= e->size - off, "file range out of bounds");
  return e->data + host_size(off);
}
static bool overlap(uint64_t a, uint64_t an, uint64_t b, uint64_t bn) {
  if (!an || !bn)
    return false;
  return a <= b ? b - a < an : a - b < bn;
}
static const char *string(const Elf *e, unsigned table, uint32_t off) {
  require(table < e->count, "bad string table index");
  const Section *s = &e->sections[table];
  require(s->type == SHT_STRTAB && off < s->size, "bad string table reference");
  const char *p = (const char *)span(e, s->offset + off, s->size - off);
  require(memchr(p, 0, host_size(s->size - off)) != NULL,
          "unterminated string");
  return p;
}
static Symbol symbol(const Elf *e, uint64_t index) {
  require(index < e->nsyms, "bad symbol index");
  const unsigned char *p =
      span(e, e->sections[e->symtab].offset + index * 24, 24);
  Symbol s = {(uint32_t)get(p, 4),     p[4],          p[5],
              (uint16_t)get(p + 6, 2), get(p + 8, 8), get(p + 16, 8)};
  return s;
}
static Symbol unique(const Elf *e, const char *name) {
  Symbol found = {0};
  unsigned matches = 0;
  for (uint64_t i = 0; i < e->nsyms; ++i) {
    Symbol s = symbol(e, i);
    if (strcmp(string(e, e->strtab, s.name), name) == 0) {
      found = s;
      ++matches;
    }
  }
  if (matches != 1) {
    fprintf(stderr, "reject: missing/ambiguous symbol: %s\n", name);
    exit(EXIT_FAILURE);
  }
  return found;
}
static int compare_ranges(const void *a, const void *b) {
  const Range *x = a, *y = b;
  return (x->offset > y->offset) - (x->offset < y->offset);
}
static bool zero_bytes(const unsigned char *p, size_t n) {
  for (size_t i = 0; i < n; ++i)
    if (p[i])
      return false;
  return true;
}
static void parse(Elf *e) {
  const unsigned char *h = span(e, 0, 64);
  require(
      memcmp(h, "BC\300\336", 4) != 0 && memcmp(h, "\336\300\027\013", 4) != 0,
      "LLVM bitcode is unsupported; compile CUDA host objects without -flto");
  require(memcmp(h, "\177ELF\2\1\1", 7) == 0, "expected little-endian ELF64");
  e->machine = (uint16_t)get(h + 18, 2);
  require(e->machine == EM_X86_64 || e->machine == EM_AARCH64,
          "expected x86-64 or AArch64");
  require(
      get(h + 16, 2) == ET_REL && get(h + 20, 4) == EV_CURRENT &&
          get(h + 24, 8) == 0 && get(h + 32, 8) == 0 && get(h + 48, 4) == 0 &&
          get(h + 52, 2) == 64 && get(h + 56, 2) == 0,
      "expected ordinary ET_REL without program headers or processor flags");
  e->shoff = get(h + 40, 8);
  e->count = (uint16_t)get(h + 60, 2);
  e->shstr = (uint16_t)get(h + 62, 2);
  require(get(h + 58, 2) == 64 && e->count > 0 && e->count < SHN_LORESERVE &&
              e->shstr > 0 && e->shstr < e->count && e->shoff % 8 == 0,
          "unsupported section table (extended numbering is not supported)");
  span(e, e->shoff, (uint64_t)e->count * 64);
  require(zero_bytes(span(e, e->shoff, 64), 64),
          "nonempty null section header");
  e->sections = allocate((size_t)e->count * sizeof(*e->sections));
  Range *ranges = allocate(((size_t)e->count + 2) * sizeof(*ranges));
  size_t nr = 0;
  ranges[nr++] = (Range){0, 64};
  ranges[nr++] = (Range){e->shoff, (uint64_t)e->count * 64};
  unsigned symtabs = 0;
  for (unsigned i = 0; i < e->count; ++i) {
    const unsigned char *p = span(e, e->shoff + (uint64_t)i * 64, 64);
    Section s = {(uint32_t)get(p, 4),
                 (uint32_t)get(p + 4, 4),
                 (uint32_t)get(p + 40, 4),
                 (uint32_t)get(p + 44, 4),
                 get(p + 8, 8),
                 get(p + 24, 8),
                 get(p + 32, 8),
                 get(p + 48, 8),
                 get(p + 56, 8)};
    require(!s.align || (s.align & (s.align - 1)) == 0,
            "invalid section alignment");
    require(!(s.flags & SHF_COMPRESSED), "compressed sections are unsupported");
    require(s.type != SHT_REL && s.type != 19 /* RELR */ &&
                s.type != 20 /* CREL */ &&
                s.type != 0x40000014 /* experimental CREL */ &&
                s.type != SHT_SYMTAB_SHNDX && s.type != SHT_DYNSYM,
            "unsupported relocation or symbol table format");
    if (i)
      require(s.type != SHT_NULL, "unexpected null section");
    if (s.type != SHT_NOBITS) {
      span(e, s.offset, s.size);
      require(s.align <= 1 || s.offset % s.align == 0, "misaligned section");
      if (s.size)
        ranges[nr++] = (Range){s.offset, s.size};
    }
    if (s.type == SHT_SYMTAB) {
      e->symtab = (uint16_t)i;
      ++symtabs;
    }
    e->sections[i] = s;
  }
  /* Reject aliases between tables and data: patching must never alter code. */
  qsort(ranges, nr, sizeof(*ranges), compare_ranges);
  for (size_t i = 1; i < nr; ++i)
    require(!overlap(ranges[i - 1].offset, ranges[i - 1].size, ranges[i].offset,
                     ranges[i].size),
            "overlapping file regions");
  free(ranges);
  require(symtabs == 1, "expected exactly one regular symbol table");
  for (unsigned i = 0; i < e->count; ++i) {
    const char *name = string(e, e->shstr, e->sections[i].name);
    require(
        strcmp(name, ".llvm.lto") != 0 && strcmp(name, ".llvmbc") != 0 &&
            strncmp(name, ".gnu.lto_", 9) != 0,
        "embedded LTO is unsupported; compile CUDA host objects without -flto");
  }
  Section *s = &e->sections[e->symtab];
  require(s->entsize == 24 && s->size % 24 == 0 && s->link > 0 &&
              s->link < e->count && s->align <= 8 && !s->flags,
          "invalid symbol table");
  e->nsyms = s->size / 24;
  require(e->nsyms > 0 && e->nsyms <= UINT32_MAX && s->info > 0 &&
              s->info <= e->nsyms,
          "invalid symbol count or local boundary");
  e->strtab = (uint16_t)s->link;
  const Section *st = &e->sections[e->strtab];
  require(st->type == SHT_STRTAB && st->size > 0 && st->size <= UINT32_MAX &&
              st->align <= 1 && !st->flags && span(e, st->offset, 1)[0] == 0,
          "unsupported symbol string table");
  require(zero_bytes(span(e, s->offset, 24), 24), "invalid null symbol");
  for (uint64_t i = 0; i < e->nsyms; ++i) {
    Symbol x = symbol(e, i);
    string(e, e->strtab, x.name);
    require((ELF64_ST_BIND(x.info) == STB_LOCAL) == (i < s->info),
            "invalid local symbol boundary");
    require(x.section < e->count || x.section == SHN_ABS ||
                x.section == SHN_COMMON,
            "unsupported symbol section index");
  }
  for (unsigned i = 0; i < e->count; ++i) {
    const Section *r = &e->sections[i];
    if (r->type != SHT_RELA)
      continue;
    require(r->link == e->symtab && r->info > 0 && r->info < e->count &&
                r->entsize == 24 && r->size % 24 == 0,
            "invalid RELA metadata");
    for (uint64_t j = 0; j < r->size; j += 24) {
      const unsigned char *p = span(e, r->offset + j, 24);
      require((get(p + 8, 8) >> 32) < e->nsyms &&
                  get(p, 8) < e->sections[r->info].size,
              "invalid relocation bounds/symbol index");
    }
  }
}
static bool defined(const Elf *e, Symbol s) {
  return s.section > 0 && s.section < e->count;
}
static bool data_section(const Section *s) {
  return s->type == SHT_PROGBITS && (s->flags & SHF_ALLOC) &&
         !(s->flags &
           (SHF_EXECINSTR | SHF_GROUP | SHF_MERGE | SHF_STRINGS | SHF_TLS));
}
static uint64_t resolve(uint64_t value, uint64_t signed_addend) {
  if (!(signed_addend >> 63))
    return add(value, signed_addend);
  uint64_t magnitude = ~signed_addend + 1;
  require(magnitude <= value, "negative payload target");
  return value - magnitude;
}
static void validate_name(const char *name) {
  const char prefix[] = "__cuda_payload_";
  require(strncmp(name, prefix, sizeof(prefix) - 1) == 0 &&
              name[sizeof(prefix) - 1],
          "use a unique __cuda_payload_<TU-id> symbol");
  for (const unsigned char *p =
           (const unsigned char *)name + sizeof(prefix) - 1;
       *p; ++p)
    require((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
                (*p >= '0' && *p <= '9') || *p == '_',
            "invalid payload symbol name");
}
static unsigned char *redirect(const Elf *e, const char *name,
                               size_t *size_out) {
  validate_name(name);
  unsigned wrappers = 0;
  const char wrapper_name[] = "__cuda_fatbin_wrapper";
  for (uint64_t i = 0; i < e->nsyms; ++i) {
    Symbol x = symbol(e, i);
    const char *n = string(e, e->strtab, x.name);
    require(strcmp(n, name) != 0, "payload symbol already exists");
    if (strncmp(n, wrapper_name, sizeof(wrapper_name) - 1) == 0)
      ++wrappers;
  }
  require(wrappers != 0,
          "no CUDA device registration: use cc_library for host-only sources");
  require(wrappers == 1, "ambiguous wrapper family");
  Symbol w = unique(e, wrapper_name), ctor = unique(e, "__cuda_module_ctor");
  require(w.info == ELF64_ST_INFO(STB_LOCAL, STT_OBJECT) && !w.other &&
              w.size == 24 && defined(e, w),
          "unsupported wrapper symbol");
  require(ctor.info == ELF64_ST_INFO(STB_LOCAL, STT_FUNC) && ctor.size &&
              defined(e, ctor),
          "unsupported constructor symbol");
  const Section *cs = &e->sections[ctor.section];
  require(cs->type == SHT_PROGBITS && (cs->flags & SHF_EXECINSTR) &&
              ctor.value <= cs->size && ctor.size <= cs->size - ctor.value,
          "invalid constructor extent");
  const char *runtime[] = {"__cudaRegisterFatBinary",
                           "__cudaRegisterFatBinaryEnd",
                           "__cudaUnregisterFatBinary"};
  for (unsigned i = 0; i < sizeof(runtime) / sizeof(runtime[0]); ++i) {
    Symbol x = unique(e, runtime[i]);
    require(x.section == SHN_UNDEF && ELF64_ST_BIND(x.info) == STB_GLOBAL,
            "unexpected CUDA runtime symbol");
  }
  const Section *ws = &e->sections[w.section];
  require(data_section(ws) &&
              strcmp(string(e, e->shstr, ws->name), ".nvFatBinSegment") == 0,
          "unsupported wrapper section");
  require(ws->align >= 8 && w.value % 8 == 0 && w.value <= ws->size &&
              w.size <= ws->size - w.value,
          "invalid wrapper extent/alignment");
  const unsigned char *wp = span(e, ws->offset + w.value, 24);
  require(get(wp, 4) == 0x466243b1 && get(wp + 4, 4) == 1 &&
              zero_bytes(wp + 8, 16),
          "unexpected wrapper magic/version/pointer bytes");
  uint32_t absolute = e->machine == EM_X86_64 ? R_X86_64_64 : R_AARCH64_ABS64;
  uint64_t location = 0, target_index = 0, addend = 0;
  unsigned matches = 0;
  for (unsigned i = 0; i < e->count; ++i) {
    const Section *s = &e->sections[i];
    if (s->type != SHT_RELA)
      continue;
    require(s->link == e->symtab && s->info > 0 && s->info < e->count &&
                s->entsize == 24 && s->size % 24 == 0,
            "invalid RELA metadata");
    for (uint64_t j = 0; j < s->size; j += 24) {
      const unsigned char *p = span(e, s->offset + j, 24);
      uint64_t off = get(p, 8), info = get(p + 8, 8);
      require((info >> 32) < e->nsyms && off < e->sections[s->info].size,
              "invalid relocation bounds/symbol index");
      if (s->info != w.section)
        continue;
      /* Only 8-byte absolute data relocations supported in this section.
       * This makes overlap checks independent of unknown relocation widths. */
      require((uint32_t)info == absolute && ws->size - off >= 8,
              "unsupported relocation in wrapper section");
      if (!overlap(off, 8, w.value, w.size))
        continue;
      require(off == w.value + 8, "relocation is not at wrapper payload field");
      ++matches;
      location = s->offset + j;
      target_index = info >> 32;
      addend = get(p + 16, 8);
    }
  }
  require(matches == 1, "missing/ambiguous wrapper payload relocation");
  Symbol target = symbol(e, target_index);
  unsigned type = ELF64_ST_TYPE(target.info);
  require(defined(e, target) && ELF64_ST_BIND(target.info) == STB_LOCAL &&
              (type == STT_SECTION || type == STT_OBJECT) && !target.other &&
              target.size == 0,
          "unsupported original payload symbol");
  if (type == STT_SECTION)
    require(target.value == 0, "invalid section-symbol value");
  const Section *ps = &e->sections[target.section];
  require(data_section(ps) &&
              strcmp(string(e, e->shstr, ps->name), ".nv_fatbin") == 0,
          "unsupported original payload section");
  uint64_t resolved = resolve(target.value, addend);
  require(target.value <= ps->size && resolved == ps->size && ps->align >= 8 &&
              resolved % 8 == 0,
          "expected empty payload at aligned section end");

  const Section *st = &e->sections[e->strtab], *sy = &e->sections[e->symtab];
  uint64_t strings_size = add(st->size, add(strlen(name), 1));
  require(strings_size <= UINT32_MAX, "string table too large");
  uint64_t strings_off = e->size;
  uint64_t symbols_off = add(add(strings_off, strings_size), 7) & ~UINT64_C(7);
  uint64_t symbols_size = add(sy->size, 24);
  *size_out = host_size(add(symbols_off, symbols_size));
  unsigned char *out = allocate(*size_out);
  memcpy(out, e->data, e->size);
  memset(out + e->size, 0, *size_out - e->size);
  memcpy(out + strings_off, span(e, st->offset, st->size), host_size(st->size));
  memcpy(out + strings_off + st->size, name, strlen(name) + 1);
  memcpy(out + symbols_off, span(e, sy->offset, sy->size), host_size(sy->size));
  unsigned char *new_symbol = out + symbols_off + sy->size;
  put(new_symbol, 4, st->size);
  new_symbol[4] = ELF64_ST_INFO(STB_GLOBAL, STT_OBJECT);
  new_symbol[5] = STV_HIDDEN;
  /* SHN_UNDEF, value and size remain zero. Existing indices remain stable. */
  put(out + e->shoff + (uint64_t)e->strtab * 64 + 24, 8, strings_off);
  put(out + e->shoff + (uint64_t)e->strtab * 64 + 32, 8, strings_size);
  put(out + e->shoff + (uint64_t)e->symtab * 64 + 24, 8, symbols_off);
  put(out + e->shoff + (uint64_t)e->symtab * 64 + 32, 8, symbols_size);
  put(out + location + 8, 8, (e->nsyms << 32) | absolute);
  put(out + location + 16, 8, 0);
  fprintf(stderr,
          "%s: wrapper section=%u offset=0x%" PRIx64
          "; payload relocation=0x%" PRIx64 "; old=.nv_fatbin+0x%" PRIx64
          "; new=%s+0\n",
          e->machine == EM_X86_64 ? "x86-64" : "AArch64", w.section, w.value,
          w.value + 8, resolved, name);
  return out;
}
static void read_file(Elf *e, const char *path) {
  int fd = open(path, O_RDONLY);
  if (fd < 0)
    syserr("open input");
  struct stat st;
  if (fstat(fd, &st) < 0)
    syserr("fstat input");
  require(S_ISREG(st.st_mode) && st.st_size >= 64,
          "expected regular ELF input file");
  e->size = host_size((uint64_t)st.st_size);
  e->data = allocate(e->size);
  size_t done = 0;
  while (done < e->size) {
    size_t n = e->size - done;
    if (n > 1024 * 1024)
      n = 1024 * 1024;
    ssize_t got = read(fd, e->data + done, n);
    if (got < 0) {
      if (errno == EINTR)
        continue;
      syserr("read input");
    }
    require(got > 0, "short input read");
    done += (size_t)got;
  }
  if (close(fd) < 0)
    syserr("close input");
}
static void write_file(const char *path, const unsigned char *data,
                       size_t size) {
  /* Never truncate an existing output or the input (including symlink aliases).
   */
  int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0666);
  if (fd < 0)
    syserr("create output");
  size_t done = 0;
  while (done < size) {
    size_t n = size - done;
    if (n > 1024 * 1024)
      n = 1024 * 1024;
    ssize_t wrote = write(fd, data + done, n);
    if (wrote < 0 && errno == EINTR)
      continue;
    if (wrote <= 0) {
      int saved = wrote < 0 ? errno : EIO;
      close(fd);
      unlink(path);
      errno = saved;
      syserr("write output");
    }
    done += (size_t)wrote;
  }
  if (close(fd) < 0) {
    int saved = errno;
    unlink(path);
    errno = saved;
    syserr("close output");
  }
}
int main(int argc, char **argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: cuda-redirect input.o "
                    "output.o __cuda_payload_<TU-id>\n");
    return 2;
  }
  Elf e = {0};
  read_file(&e, argv[1]);
  parse(&e);
  size_t out_size;
  unsigned char *out = redirect(&e, argv[3], &out_size);
  write_file(argv[2], out, out_size);
  free(out);
  free(e.sections);
  free(e.data);
  return 0;
}
