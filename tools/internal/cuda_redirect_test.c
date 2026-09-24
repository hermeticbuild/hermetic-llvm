/* Native-only test driver. Reuse decoding helpers to locate mutation sites;
 * preservation assertions compare the actual bytes, independently of rewriting.
 */
#define main redirect_program_main
#include "cuda_redirect.c"
#undef main
#include <sys/wait.h>

static void dispose(Elf *e) {
  free(e->sections);
  free(e->data);
}
static void load(Elf *e, const char *path) {
  read_file(e, path);
  parse(e);
}
static uint64_t payload_relocation(const Elf *e) {
  Symbol w = unique(e, "__cuda_fatbin_wrapper");
  for (unsigned i = 0; i < e->count; ++i) {
    const Section *s = &e->sections[i];
    if (s->type != SHT_RELA || s->info != w.section)
      continue;
    for (uint64_t j = 0; j < s->size; j += 24)
      if (get(e->data + s->offset + j, 8) == w.value + 8)
        return s->offset + j;
  }
  require(false, "fixture lacks payload relocation");
  return 0;
}
static uint64_t symbol_offset(const Elf *e, const char *name) {
  for (uint64_t i = 0; i < e->nsyms; ++i) {
    Symbol s = symbol(e, i);
    if (!strcmp(string(e, e->strtab, s.name), name))
      return e->sections[e->symtab].offset + i * 24;
  }
  require(false, "fixture lacks symbol");
  return 0;
}
static void preserve(const char *old_path, const char *new_path,
                     const char *name) {
  Elf a = {0}, b = {0};
  load(&a, old_path);
  load(&b, new_path);
  uint64_t r = payload_relocation(&a);
  Range allowed[] = {{r + 8, 16},
                     {a.shoff + (uint64_t)a.strtab * 64 + 24, 16},
                     {a.shoff + (uint64_t)a.symtab * 64 + 24, 16}};
  require(b.size > a.size && a.count == b.count && b.nsyms == a.nsyms + 1,
          "wrong output structure");
  for (size_t i = 0; i < a.size; ++i) {
    bool skip = false;
    for (unsigned j = 0; j < 3; ++j)
      if (overlap(i, 1, allowed[j].offset, allowed[j].size))
        skip = true;
    require(skip || a.data[i] == b.data[i],
            "unexpected original-byte modification");
  }
  const Section *asy = &a.sections[a.symtab], *bsy = &b.sections[b.symtab];
  const Section *ast = &a.sections[a.strtab], *bst = &b.sections[b.strtab];
  require(memcmp(span(&a, asy->offset, asy->size),
                 span(&b, bsy->offset, asy->size), host_size(asy->size)) == 0,
          "existing symbol records changed");
  require(memcmp(span(&a, ast->offset, ast->size),
                 span(&b, bst->offset, ast->size), host_size(ast->size)) == 0,
          "existing string table changed");
  Symbol s = unique(&b, name);
  require(s.info == ELF64_ST_INFO(STB_GLOBAL, STT_OBJECT) &&
              s.other == STV_HIDDEN && !s.section && !s.value && !s.size,
          "wrong inserted symbol");
  uint32_t type = a.machine == EM_X86_64 ? R_X86_64_64 : R_AARCH64_ABS64;
  require(get(b.data + r + 8, 8) == (a.nsyms << 32 | type) &&
              get(b.data + r + 16, 8) == 0,
          "wrong redirected relocation");
  printf("PASS byte preservation: %s\n", new_path);
  dispose(&a);
  dispose(&b);
}
static void child(const char *tool, const char *input, const char *output,
                  const char *name, int expected, const char *log) {
  fflush(NULL);
  pid_t pid = fork();
  if (pid < 0)
    syserr("fork");
  if (!pid) {
    int fd = open(log, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd < 0 || dup2(fd, STDERR_FILENO) < 0)
      _exit(125);
    close(fd);
    execl(tool, tool, input, output, name, (char *)NULL);
    _exit(126);
  }
  int status;
  while (waitpid(pid, &status, 0) < 0)
    if (errno != EINTR)
      syserr("waitpid");
  FILE *f = fopen(log, "rb");
  if (!f)
    syserr("read child log");
  char text[8192];
  size_t n = fread(text, 1, sizeof(text) - 1, f);
  text[n] = 0;
  fclose(f);
  require(!strstr(text, "AddressSanitizer") &&
              !strstr(text, "runtime error:") &&
              !strstr(text, "UndefinedBehaviorSanitizer"),
          "sanitizer error in CLI");
  if (!WIFEXITED(status) || WEXITSTATUS(status) != expected) {
    fprintf(stderr, "child diagnostic: %s\n", text);
    require(false, "unexpected CLI status");
  }
  printf("PASS CLI %s: %s", expected ? "reject" : "accept", text);
}
static void mutation(const Elf *e, const char *tool, const char *dir,
                     unsigned number, const char *label, uint64_t off,
                     unsigned width, uint64_t value) {
  char input[4096], output[4096], log[4096];
  require(snprintf(input, sizeof(input), "%s/%02u.o", dir, number) <
              (int)sizeof(input),
          "path too long");
  require(snprintf(output, sizeof(output), "%s/%02u.out", dir, number) <
              (int)sizeof(output),
          "path too long");
  require(snprintf(log, sizeof(log), "%s/%02u.log", dir, number) <
              (int)sizeof(log),
          "path too long");
  unsigned char *d = allocate(e->size);
  memcpy(d, e->data, e->size);
  require(off <= e->size && width <= e->size - off, "bad test mutation");
  put(d + off, width, value);
  write_file(input, d, e->size);
  free(d);
  printf("%s: ", label);
  child(tool, input, output, "__cuda_payload_test", 1, log);
  require(access(output, F_OK) != 0, "invalid input created output");
}
static void reject_cases(const char *tool, const char *path, const char *dir) {
  require(mkdir(dir, 0700) == 0,
          "test directory already exists or cannot be created");
  Elf e = {0};
  load(&e, path);
  Symbol w = unique(&e, "__cuda_fatbin_wrapper");
  uint64_t wo = symbol_offset(&e, "__cuda_fatbin_wrapper"),
           r = payload_relocation(&e);
  uint64_t wp = e.sections[w.section].offset + w.value;
  uint64_t sh = e.shoff + (uint64_t)w.section * 64;
  uint64_t rs = 0;
  for (unsigned i = 0; i < e.count; ++i)
    if (e.sections[i].type == SHT_RELA && e.sections[i].info == w.section)
      rs = e.shoff + (uint64_t)i * 64;
  unsigned n = 0;
#define BAD(label, off, width, value)                                          \
  mutation(&e, tool, dir, n++, label, off, width, value)
  BAD("ELF32", 4, 1, ELFCLASS32);
  BAD("big endian", 5, 1, ELFDATA2MSB);
  BAD("unsupported machine", 18, 2, EM_RISCV);
  BAD("wrong arch relocation pairing", 18, 2,
      e.machine == EM_X86_64 ? EM_AARCH64 : EM_X86_64);
  BAD("executable", 16, 2, ET_EXEC);
  BAD("extended numbering", 60, 2, 0);
  BAD("bad section table", 40, 8, UINT64_MAX - 7);
  BAD("bad magic", wp, 4, 0);
  BAD("bad version", wp + 4, 4, 2);
  BAD("nonzero reserved pointer", wp + 16, 8, 1);
  BAD("nonzero payload bytes", wp + 8, 8, 1);
  BAD("wrong wrapper size", wo + 16, 8, 32);
  BAD("wrapper extent overflow", wo + 8, 8, UINT64_MAX - 7);
  BAD("missing wrapper name", wo, 4, 0);
  BAD("ambiguous wrapper", symbol_offset(&e, "__cuda_module_ctor"), 4, w.name);
  BAD("global wrapper", wo + 4, 1, ELF64_ST_INFO(STB_GLOBAL, STT_OBJECT));
  BAD("bad alignment", sh + 48, 8, 3);
  BAD("bad section range", sh + 24, 8, UINT64_MAX);
  BAD("overlapping sections", sh + 24, 8, e.sections[e.symtab].offset);
  BAD("wrong relocation", r + 8, 8,
      (get(e.data + r + 8, 8) & UINT64_C(0xffffffff00000000)) | 2);
  BAD("bad relocation offset", r, 8, w.value + 16);
  BAD("bad relocation index", r + 8, 8, UINT64_MAX);
  BAD("positive addend", r + 16, 8, 8);
  BAD("negative addend", r + 16, 8, UINT64_MAX);
  BAD("INT64_MIN addend", r + 16, 8, UINT64_C(0x8000000000000000));
  BAD("wrong relocation target section", rs + 44, 4, 0);
  BAD("wrong symbol table link", rs + 40, 4, 0);
  BAD("REL format", rs + 4, 4, SHT_REL);
  BAD("CREL format", rs + 4, 4, 20);
  BAD("partial relocation record", rs + 32, 8, 23);
  BAD("unterminated symbol string",
      e.sections[e.strtab].offset + e.sections[e.strtab].size - 1, 1, 'X');
#undef BAD
  char input[4096], output[4096], log[4096];
  require(strlen(dir) + 32 < sizeof(input), "path too long");
  snprintf(input, sizeof(input), "%s/duplicate.o", dir);
  snprintf(output, sizeof(output), "%s/duplicate.out", dir);
  snprintf(log, sizeof(log), "%s/duplicate.log", dir);
  size_t off = (e.size + 7) & ~(size_t)7;
  unsigned char *d = allocate(off + 48);
  memcpy(d, e.data, e.size);
  memset(d + e.size, 0, off + 48 - e.size);
  memcpy(d + off, e.data + r, 24);
  memcpy(d + off + 24, e.data + r, 24);
  put(d + rs + 24, 8, off);
  put(d + rs + 32, 8, 48);
  write_file(input, d, off + 48);
  free(d);
  child(tool, input, output, "__cuda_payload_test", 1, log);
  require(access(output, F_OK) != 0, "duplicate relocation created output");
  snprintf(input, sizeof(input), "%s/truncated.o", dir);
  write_file(input, e.data, 63);
  child(tool, input, output, "__cuda_payload_test", 1, log);
  /* A named local zero-size payload object is also a supported relocation
   * target. */
  snprintf(input, sizeof(input), "%s/named.o", dir);
  snprintf(output, sizeof(output), "%s/named.out", dir);
  uint64_t ti = get(e.data + r + 8, 8) >> 32;
  d = allocate(e.size);
  memcpy(d, e.data, e.size);
  uint64_t to = e.sections[e.symtab].offset + ti * 24;
  /* Name from existing symbol strings, without growing the input tables. */
  put(d + to, 4, symbol(&e, 1).name);
  d[to + 4] = ELF64_ST_INFO(STB_LOCAL, STT_OBJECT);
  write_file(input, d, e.size);
  free(d);
  child(tool, input, output, "__cuda_payload_test", 0, log);
  preserve(input, output, "__cuda_payload_test");
  /* Collision, already-redirected, output clobber, bad name, and input alias.
   */
  char other[4096];
  snprintf(other, sizeof(other), "%s/never-created.o", dir);
  child(tool, output, other, "__cuda_payload_test", 1, log);
  child(tool, output, other, "__cuda_payload_other", 1, log);
  child(tool, input, other, "not-a-payload-name", 1, log);
  child(tool, input, output, "__cuda_payload_other", 1, log);
  preserve(input, output, "__cuda_payload_test");
  child(tool, path, path, "__cuda_payload_test", 1, log);
  Elf unchanged = {0};
  read_file(&unchanged, path);
  require(unchanged.size == e.size && !memcmp(e.data, unchanged.data, e.size),
          "input changed");
  require(access(other, F_OK) != 0, "invalid operation created output");
  free(unchanged.data);
  dispose(&e);
}
int main(int argc, char **argv) {
  if (argc == 5 && !strcmp(argv[1], "preserve"))
    preserve(argv[2], argv[3], argv[4]);
  else if (argc == 5 && !strcmp(argv[1], "reject"))
    reject_cases(argv[2], argv[3], argv[4]);
  else {
    fprintf(stderr, "usage: test-elf preserve old new symbol | "
                    "reject tool raw directory\n");
    return 2;
  }
  return 0;
}
