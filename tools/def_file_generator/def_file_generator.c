#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <io.h>
#include <process.h>
#include <windows.h>
#else
#include <sys/wait.h>
#include <unistd.h>
#endif

static unsigned long process_id(void) {
#if defined(_WIN32)
  return (unsigned long)_getpid();
#else
  return (unsigned long)getpid();
#endif
}

struct string_list {
  char **values;
  size_t count;
  size_t capacity;
};

struct symbol_sets {
  struct string_list symbols;
  struct string_list data_symbols;
};

/* Which linker's export-all rules to follow, selected via
 * DEF_FILE_GENERATOR_ABI. */
enum abi {
  /* CMake's bindexplib, as used by link.exe and lld-link. */
  ABI_MSVC,
  /* lld's MinGW auto-export. */
  ABI_GNU,
};

static void *xrealloc(void *pointer, size_t size) {
  void *result = realloc(pointer, size == 0 ? 1 : size);
  if (result == NULL) {
    fprintf(stderr, "def_file_generator: out of memory\n");
    exit(2);
  }
  return result;
}

static char *xstrdup(const char *value) {
  size_t size = strlen(value) + 1;
  char *result = xrealloc(NULL, size);
  memcpy(result, value, size);
  return result;
}

static void string_list_append(struct string_list *list, const char *value) {
  if (list->count == list->capacity) {
    list->capacity = list->capacity == 0 ? 32 : list->capacity * 2;
    list->values =
        xrealloc(list->values, list->capacity * sizeof(*list->values));
  }
  list->values[list->count++] = xstrdup(value);
}

static void string_set_insert(struct string_list *set, const char *value) {
  size_t position = 0;
  while (position < set->count && strcmp(set->values[position], value) < 0) {
    ++position;
  }
  if (position < set->count && strcmp(set->values[position], value) == 0) {
    return;
  }
  if (set->count == set->capacity) {
    set->capacity = set->capacity == 0 ? 32 : set->capacity * 2;
    set->values = xrealloc(set->values, set->capacity * sizeof(*set->values));
  }
  memmove(set->values + position + 1, set->values + position,
          (set->count - position) * sizeof(*set->values));
  set->values[position] = xstrdup(value);
  set->count++;
}

static int string_set_contains(const struct string_list *set,
                               const char *value) {
  size_t low = 0;
  size_t high = set->count;
  while (low < high) {
    size_t middle = low + (high - low) / 2;
    int comparison = strcmp(set->values[middle], value);
    if (comparison == 0)
      return 1;
    if (comparison < 0) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return 0;
}

static void string_set_remove_at(struct string_list *set, size_t position) {
  free(set->values[position]);
  memmove(set->values + position, set->values + position + 1,
          (set->count - position - 1) * sizeof(*set->values));
  set->count--;
}

static void string_list_destroy(struct string_list *list) {
  size_t index;
  for (index = 0; index < list->count; ++index) {
    free(list->values[index]);
  }
  free(list->values);
}

static char *read_line(FILE *file) {
  char *line = NULL;
  size_t length = 0;
  size_t capacity = 0;
  int character;
  while ((character = fgetc(file)) != EOF) {
    if (length + 1 >= capacity) {
      capacity = capacity == 0 ? 256 : capacity * 2;
      line = xrealloc(line, capacity);
    }
    if (character == '\n') {
      break;
    }
    line[length++] = (char)character;
  }
  if (character == EOF && length == 0) {
    free(line);
    return NULL;
  }
  if (line == NULL) {
    line = xrealloc(NULL, 1);
  }
  line[length] = '\0';
  return line;
}

static char *trim(char *value) {
  char *end;
  while (isspace((unsigned char)*value)) {
    ++value;
  }
  end = value + strlen(value);
  while (end != value && isspace((unsigned char)end[-1])) {
    --end;
  }
  *end = '\0';
  return value;
}

static int decode_shell_argument(char *value, char **argument) {
  char *input = value;
  char *output = value;
  int quote = 0;
  int started = 0;
  int separated = 0;

  while (*input != '\0') {
    unsigned char character = (unsigned char)*input++;
    if (quote == '\'') {
      if (character == '\'') {
        quote = 0;
      } else {
        *output++ = (char)character;
      }
    } else if (quote == '"') {
      if (character == '"') {
        quote = 0;
      } else if (character == '\\') {
        if (*input == '\0') {
          fprintf(stderr,
                  "def_file_generator: trailing escape in shell parameter\n");
          return 0;
        }
        *output++ = *input++;
      } else {
        *output++ = (char)character;
      }
    } else if (isspace(character)) {
      separated = started;
    } else {
      if (separated) {
        fprintf(stderr, "def_file_generator: multiple arguments in one shell "
                        "parameter entry\n");
        return 0;
      }
      started = 1;
      if (character == '\'' || character == '"') {
        quote = character;
      } else if (character == '\\') {
        if (*input == '\0') {
          fprintf(stderr,
                  "def_file_generator: trailing escape in shell parameter\n");
          return 0;
        }
        *output++ = *input++;
      } else {
        *output++ = (char)character;
      }
    }
  }

  if (quote != 0) {
    fprintf(stderr, "def_file_generator: unterminated shell parameter quote\n");
    return 0;
  }
  if (!started) {
    fprintf(stderr, "def_file_generator: empty shell parameter entry\n");
    return 0;
  }
  *output = '\0';
  *argument = value;
  return 1;
}

#if defined(_WIN32)

static wchar_t *utf8_to_wide(const char *value) {
  int length;
  wchar_t *wide;
  if (value[0] == '\0') {
    wide = xrealloc(NULL, sizeof(*wide));
    wide[0] = L'\0';
    return wide;
  }
  length = MultiByteToWideChar(CP_UTF8, 0, value, -1, NULL, 0);
  if (length <= 0) {
    return NULL;
  }
  wide = xrealloc(NULL, (size_t)length * sizeof(*wide));
  if (MultiByteToWideChar(CP_UTF8, 0, value, -1, wide, length) <= 0) {
    free(wide);
    return NULL;
  }
  return wide;
}

static FILE *open_file(const char *path, const char *mode) {
  wchar_t *wide_path = utf8_to_wide(path);
  wchar_t *wide_mode = utf8_to_wide(mode);
  FILE *file = wide_path == NULL || wide_mode == NULL
                   ? NULL
                   : _wfopen(wide_path, wide_mode);
  free(wide_path);
  free(wide_mode);
  return file;
}

static int remove_file(const char *path) {
  wchar_t *wide_path = utf8_to_wide(path);
  int result = wide_path == NULL ? -1 : _wremove(wide_path);
  free(wide_path);
  return result;
}

static int run(const char *const argv[], FILE *stdout_file) {
  int saved_out;
  size_t argc = 0;
  wchar_t **wide_argv;
  intptr_t child;
  int status;

  saved_out = _dup(_fileno(stdout));
  if (saved_out < 0 || _dup2(_fileno(stdout_file), _fileno(stdout)) != 0) {
    fprintf(stderr, "def_file_generator: could not redirect llvm-nm: %s\n",
            strerror(errno));
    if (saved_out >= 0)
      _close(saved_out);
    return 0;
  }
  while (argv[argc] != NULL)
    ++argc;
  wide_argv = xrealloc(NULL, (argc + 1) * sizeof(*wide_argv));
  for (size_t index = 0; index < argc; ++index) {
    wide_argv[index] = utf8_to_wide(argv[index]);
    if (wide_argv[index] == NULL) {
      fprintf(stderr, "def_file_generator: invalid UTF-8 argument\n");
      while (index != 0)
        free(wide_argv[--index]);
      free(wide_argv);
      _dup2(saved_out, _fileno(stdout));
      _close(saved_out);
      return 0;
    }
  }
  wide_argv[argc] = NULL;
  child = _wspawnv(_P_NOWAIT, wide_argv[0], (const wchar_t *const *)wide_argv);
  for (size_t index = 0; index < argc; ++index)
    free(wide_argv[index]);
  free(wide_argv);
  _dup2(saved_out, _fileno(stdout));
  _close(saved_out);
  if (child == -1 || _cwait(&status, child, 0) == -1) {
    fprintf(stderr, "def_file_generator: could not run llvm-nm: %s\n",
            strerror(errno));
    return 0;
  }
  if (status != 0) {
    fprintf(stderr, "def_file_generator: llvm-nm exited with status %d\n",
            status);
    return 0;
  }
  return 1;
}

#else

static FILE *open_file(const char *path, const char *mode) {
  return fopen(path, mode);
}

static int remove_file(const char *path) { return remove(path); }

static int run(const char *const argv[], FILE *stdout_file) {
  pid_t child = fork();
  int status;
  if (child < 0) {
    fprintf(stderr, "def_file_generator: could not fork llvm-nm: %s\n",
            strerror(errno));
    return 0;
  }
  if (child == 0) {
    if (dup2(fileno(stdout_file), STDOUT_FILENO) < 0)
      _exit(127);
    execv(argv[0], (char *const *)argv);
    fprintf(stderr, "def_file_generator: execv(%s): %s\n", argv[0],
            strerror(errno));
    _exit(127);
  }
  if (waitpid(child, &status, 0) < 0) {
    fprintf(stderr, "def_file_generator: waitpid: %s\n", strerror(errno));
    return 0;
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    fprintf(stderr, "def_file_generator: llvm-nm exited with status %d\n",
            WIFEXITED(status) ? WEXITSTATUS(status) : -1);
    return 0;
  }
  return 1;
}

#endif

static const char *required_env(const char *name) {
  const char *value = getenv(name);
  if (value == NULL || value[0] == '\0') {
    fprintf(stderr, "def_file_generator: required env var %s is not set\n",
            name);
    exit(2);
  }
  return value;
}

static int is_definition_file(const char *filename) {
  const char *extension = strrchr(filename, '.');
  const char *value = extension == NULL ? filename : extension + 1;
  return strlen(value) == 3 && tolower((unsigned char)value[0]) == 'd' &&
         tolower((unsigned char)value[1]) == 'e' &&
         tolower((unsigned char)value[2]) == 'f';
}

static int merge_definition_file(struct symbol_sets *sets,
                                 const char *filename) {
  FILE *file = open_file(filename, "rb");
  char *line;
  if (file == NULL) {
    fprintf(stderr, "Could not open definition file: %s\n", filename);
    return 0;
  }
  while ((line = read_line(file)) != NULL) {
    if (strncmp(line, "LIBRARY", 7) != 0 && strncmp(line, "EXPORTS", 7) != 0) {
      char *symbol = line;
      char *data;
      while (*symbol == ' ' || *symbol == '\t')
        ++symbol;
      data = strstr(symbol, " \t DATA");
      if (data != NULL) {
        *data = '\0';
        string_set_insert(&sets->data_symbols, symbol);
      } else if (*symbol != '\0') {
        string_set_insert(&sets->symbols, symbol);
      }
    }
    free(line);
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "Could not read definition file: %s\n", filename);
    return 0;
  }
  return 1;
}

static int contains(const char *value, const char *substring) {
  return strstr(value, substring) != NULL;
}

static int managed_symbol(const char *symbol) {
  return strcmp(symbol, "__t2m") == 0 || strcmp(symbol, "__m2mep") == 0 ||
         strcmp(symbol, "__mep") == 0 || contains(symbol, "$$F") ||
         contains(symbol, "$$J");
}

static void normalize_stdcall(char *symbol) {
  char *at;
  char *digit;
  if (symbol[0] != '_')
    return;
  at = strrchr(symbol, '@');
  if (at == NULL || at[1] == '\0')
    return;
  for (digit = at + 1; *digit != '\0'; ++digit) {
    if (!isdigit((unsigned char)*digit))
      return;
  }
  *at = '\0';
  memmove(symbol, symbol + 1, strlen(symbol));
}

static int has_prefix(const char *value, const char *prefix) {
  return strncmp(value, prefix, strlen(prefix)) == 0;
}

static int has_suffix(const char *value, const char *suffix) {
  size_t value_length = strlen(value);
  size_t suffix_length = strlen(suffix);
  return value_length >= suffix_length &&
         strcmp(value + value_length - suffix_length, suffix) == 0;
}

/* lld's excludeSymbols for targets other than i386, plus the ARM64EC ones, see
 * https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/lld/COFF/MinGW.cpp#L110-L131
 */
static const char *const gnu_excluded_symbols[] = {
    "__NULL_IMPORT_DESCRIPTOR",
    "_pei386_runtime_relocator",
    "do_pseudo_reloc",
    "impure_ptr",
    "_impure_ptr",
    "_fmode",
    "environ",
    "__dso_handle",
    "_load_config_used",
    "DllMain",
    "DllEntryPoint",
    "DllMainCRTStartup",
    "__chpe_metadata",
};

/* lld's excludeSymbolPrefixes, plus the ones for targets other than i386 and
 * for ARM64EC, see
 * https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/lld/COFF/MinGW.cpp#L69-L84
 * and
 * https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/lld/COFF/MinGW.cpp#L126-L130
 */
static const char *const gnu_excluded_prefixes[] = {
    "__imp_",       "__IMPORT_DESCRIPTOR_",
    "__nm_",        "__rtti_",
    "__builtin_",   ".",
    "__profc_",     "__profd_",
    "__profvp_",    "_head_",
    "__os_arm64x_",
};

/* lld's excludeSymbolSuffixes, see
 * https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/lld/COFF/MinGW.cpp#L86-L89
 */
static const char *const gnu_excluded_suffixes[] = {
    "_iname",
    "_NULL_THUNK_DATA",
};

#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

static int gnu_excluded_symbol(const char *symbol) {
  size_t index;
  for (index = 0; index < ARRAY_SIZE(gnu_excluded_symbols); ++index) {
    if (strcmp(symbol, gnu_excluded_symbols[index]) == 0)
      return 1;
  }
  for (index = 0; index < ARRAY_SIZE(gnu_excluded_prefixes); ++index) {
    if (has_prefix(symbol, gnu_excluded_prefixes[index]))
      return 1;
  }
  for (index = 0; index < ARRAY_SIZE(gnu_excluded_suffixes); ++index) {
    if (has_suffix(symbol, gnu_excluded_suffixes[index]))
      return 1;
  }
  return 0;
}

/* Unlike bindexplib, lld's MinGW auto-export includes read-only data such as
 * vtables and typeinfo, see
 * https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/lld/COFF/MinGW.cpp#L145-L166
 */
static int add_gnu_nm_symbol(struct symbol_sets *sets, const char *symbol,
                             char type) {
  if (symbol[0] == '\0' || !isupper((unsigned char)type) || type == 'U' ||
      type == 'V' || type == 'W' || type == 'I' || type == 'N' ||
      gnu_excluded_symbol(symbol)) {
    return 1;
  }
  if (type == 'T') {
    string_set_insert(&sets->symbols, symbol);
  } else {
    string_set_insert(&sets->data_symbols, symbol);
  }
  return 1;
}

/* lld doesn't auto-export symbols whose __imp_ pointer is defined, see
 * https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/lld/COFF/MinGW.cpp#L164-L166
 */
static void remove_imported_symbols(struct symbol_sets *sets,
                                    const struct string_list *import_pointers) {
  struct string_list *lists[2];
  size_t list_index;
  lists[0] = &sets->symbols;
  lists[1] = &sets->data_symbols;
  for (list_index = 0; list_index < 2; ++list_index) {
    struct string_list *list = lists[list_index];
    size_t index = 0;
    while (index < list->count) {
      if (string_set_contains(import_pointers, list->values[index])) {
        string_set_remove_at(list, index);
      } else {
        ++index;
      }
    }
  }
}

static int add_nm_symbol(struct symbol_sets *sets, char *symbol, char type) {
  normalize_stdcall(symbol);
  if (symbol[0] == '\0' || !isupper((unsigned char)type) || type == 'U' ||
      type == 'V' || type == 'W' || type == 'C' ||
      (type == 'R' && strncmp(symbol, "??_7", 4) != 0) ||
      strncmp(symbol, "??_G", 4) == 0 || strncmp(symbol, "??_E", 4) == 0 ||
      strchr(symbol, '.') != NULL || managed_symbol(symbol) ||
      contains(symbol, "$ientry_thunk") || contains(symbol, "$entry_thunk") ||
      contains(symbol, "$iexit_thunk") || contains(symbol, "$exit_thunk")) {
    return 1;
  }
  if (type == 'B' || type == 'D' || type == 'G' || type == 'S') {
    string_set_insert(&sets->data_symbols, symbol);
  } else {
    string_set_insert(&sets->symbols, symbol);
  }
  return 1;
}

static int parse_nm_output(struct symbol_sets *sets, FILE *output, enum abi abi,
                           struct string_list *import_pointers) {
  char *line;
  rewind(output);
  while ((line = read_line(output)) != NULL) {
    char *separator = NULL;
    char *candidate = line;
    char *symbol;
    char *space;
    char type;
    while ((candidate = strstr(candidate, ": ")) != NULL) {
      separator = candidate;
      candidate += 2;
    }
    if (separator == NULL) {
      if (*trim(line) != '\0') {
        fprintf(stderr, "def_file_generator: malformed llvm-nm output: %s\n",
                line);
        free(line);
        return 0;
      }
      free(line);
      continue;
    }
    symbol = separator + 2;
    space = symbol;
    while (*space != '\0' && !isspace((unsigned char)*space))
      ++space;
    if (*space == '\0') {
      fprintf(stderr, "def_file_generator: malformed llvm-nm output: %s\n",
              line);
      free(line);
      return 0;
    }
    *space++ = '\0';
    while (isspace((unsigned char)*space))
      ++space;
    type = *space;
    if (abi == ABI_GNU) {
      if (isupper((unsigned char)type) && type != 'U' &&
          has_prefix(symbol, "__imp_")) {
        string_set_insert(import_pointers, symbol + strlen("__imp_"));
      }
      add_gnu_nm_symbol(sets, symbol, type);
    } else {
      add_nm_symbol(sets, symbol, type);
    }
    free(line);
  }
  return !ferror(output);
}

static int discover_object_symbols(struct symbol_sets *sets,
                                   const struct string_list *objects,
                                   const char *response_path, enum abi abi) {
  struct string_list import_pointers = {0};
  FILE *response;
  FILE *output;
  char *response_argument;
  const char *arguments[7];
  int success;
  size_t index;

  if (objects->count == 0)
    return 1;
  response = open_file(response_path, "wb");
  if (response == NULL) {
    fprintf(stderr, "Could not open llvm-nm parameter file: %s\n",
            response_path);
    return 0;
  }
  for (index = 0; index < objects->count; ++index) {
    if (strchr(objects->values[index], '"') != NULL ||
        fprintf(response, "\"%s\"\n", objects->values[index]) < 0) {
      fprintf(stderr, "Could not write llvm-nm parameter file: %s\n",
              response_path);
      fclose(response);
      remove_file(response_path);
      return 0;
    }
  }
  if (fclose(response) != 0) {
    fprintf(stderr, "Could not write llvm-nm parameter file: %s\n",
            response_path);
    remove_file(response_path);
    return 0;
  }

  response_argument = xrealloc(NULL, strlen(response_path) + 2);
  response_argument[0] = '@';
  strcpy(response_argument + 1, response_path);
  arguments[0] = required_env("LLVM_NM");
  arguments[1] = "-A";
  arguments[2] = "-g";
  arguments[3] = "--defined-only";
  arguments[4] = "--format=posix";
  arguments[5] = response_argument;
  arguments[6] = NULL;
  output = tmpfile();
  if (output == NULL) {
    fprintf(stderr, "def_file_generator: tmpfile: %s\n", strerror(errno));
    free(response_argument);
    remove_file(response_path);
    return 0;
  }
  success = run(arguments, output) &&
            parse_nm_output(sets, output, abi, &import_pointers);
  if (success)
    remove_imported_symbols(sets, &import_pointers);
  string_list_destroy(&import_pointers);
  fclose(output);
  free(response_argument);
  if (remove_file(response_path) != 0) {
    fprintf(stderr, "Could not remove llvm-nm parameter file: %s\n",
            response_path);
    return 0;
  }
  return success;
}

static int add_input(struct symbol_sets *sets, struct string_list *objects,
                     const char *filename) {
  if (is_definition_file(filename)) {
    return merge_definition_file(sets, filename);
  }
  string_list_append(objects, filename);
  return 1;
}

static int expand_inputs(struct symbol_sets *sets, struct string_list *objects,
                         int argc, char **argv) {
  int index;
  for (index = 3; index < argc; ++index) {
    if (argv[index][0] == '@') {
      FILE *parameters = open_file(argv[index] + 1, "rb");
      char *line;
      if (parameters == NULL) {
        fprintf(stderr, "Could not open parameter file: %s\n", argv[index]);
        return 0;
      }
      while ((line = read_line(parameters)) != NULL) {
        char *filename;
        if (!decode_shell_argument(trim(line), &filename) ||
            !add_input(sets, objects, filename)) {
          free(line);
          fclose(parameters);
          return 0;
        }
        free(line);
      }
      if (fclose(parameters) != 0)
        return 0;
    } else if (!add_input(sets, objects, trim(argv[index]))) {
      return 0;
    }
  }
  return 1;
}

static int write_def_file(const struct symbol_sets *sets, const char *path,
                          const char *dll_name) {
  FILE *output = open_file(path, "wb");
  size_t index;
  if (output == NULL) {
    fprintf(stderr, "Could not open output .def file: %s\n", path);
    return 0;
  }
  if (dll_name[0] != '\0')
    fprintf(output, "LIBRARY %s\n", dll_name);
  fprintf(output, "EXPORTS \n");
  for (index = 0; index < sets->data_symbols.count; ++index) {
    fprintf(output, "\t%s \t DATA\n", sets->data_symbols.values[index]);
  }
  for (index = 0; index < sets->symbols.count; ++index) {
    fprintf(output, "\t%s\n", sets->symbols.values[index]);
  }
  if (fclose(output) != 0) {
    fprintf(stderr, "Could not write output .def file: %s\n", path);
    return 0;
  }
  return 1;
}

static int parse_abi(enum abi *abi) {
  const char *value = getenv("DEF_FILE_GENERATOR_ABI");
  if (value == NULL || value[0] == '\0' || strcmp(value, "msvc") == 0) {
    *abi = ABI_MSVC;
  } else if (strcmp(value, "gnu") == 0) {
    *abi = ABI_GNU;
  } else {
    fprintf(stderr,
            "def_file_generator: DEF_FILE_GENERATOR_ABI must be 'msvc' or "
            "'gnu', got '%s'\n",
            value);
    return 0;
  }
  return 1;
}

static void usage(void) {
  fprintf(stderr,
          "Usage: output_def_file dllname [objfile ...] [input_deffile ...] "
          "[@paramfile ...]\n");
}

int main(int argc, char **argv) {
  struct symbol_sets sets = {0};
  struct string_list objects = {0};
  char *nm_response_path;
  enum abi abi;
  int success;

  if (argc < 4) {
    usage();
    return 1;
  }
  if (!parse_abi(&abi))
    return 1;
  success = expand_inputs(&sets, &objects, argc, argv);
  nm_response_path = xrealloc(NULL, 64);
  snprintf(nm_response_path, 64, ".def-file-generator-%lu.rsp", process_id());
  if (success) {
    success = discover_object_symbols(&sets, &objects, nm_response_path, abi);
  }
  if (success)
    success = write_def_file(&sets, argv[1], argv[2]);
  free(nm_response_path);
  string_list_destroy(&objects);
  string_list_destroy(&sets.symbols);
  string_list_destroy(&sets.data_symbols);
  return success ? 0 : 1;
}
