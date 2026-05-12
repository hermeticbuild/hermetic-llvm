/*
 * Assembles the libstdc++ linker version script from GCC's base
 * config/abi/pre/gnu.ver file and optional per-target port fragments. GCC's
 * makefiles either append a port fragment or splice it after the introductory
 * comment block; this helper reproduces that small text transform without
 * shell-dependent sed/awk logic.
 */
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct File {
  char *data;
  size_t len;
};

static void PrintErrno(const char *path) {
  fprintf(stderr, "libstdcxx-symbols-assembler: %s: %s\n", path,
          strerror(errno));
}

static int ReadFile(const char *path, struct File *out) {
  FILE *file = fopen(path, "rb");
  long size;

  if (!file) {
    PrintErrno(path);
    return 0;
  }
  if (fseek(file, 0, SEEK_END) != 0 || (size = ftell(file)) < 0 ||
      fseek(file, 0, SEEK_SET) != 0) {
    PrintErrno(path);
    fclose(file);
    return 0;
  }

  out->data = (char *)malloc((size_t)size + 1);
  out->len = (size_t)size;
  if (!out->data) {
    PrintErrno("malloc");
    fclose(file);
    return 0;
  }
  if (out->len && fread(out->data, 1, out->len, file) != out->len) {
    PrintErrno(path);
    fclose(file);
    return 0;
  }
  out->data[out->len] = '\0';
  if (fclose(file) != 0) {
    PrintErrno(path);
    return 0;
  }
  return 1;
}

static int WriteFile(const char *path, const struct File *file) {
  FILE *out = fopen(path, "wb");
  if (!out) {
    PrintErrno(path);
    return 0;
  }
  if (file->len && fwrite(file->data, 1, file->len, out) != file->len) {
    PrintErrno(path);
    fclose(out);
    return 0;
  }
  if (fclose(out) != 0) {
    PrintErrno(path);
    return 0;
  }
  return 1;
}

static int Append(struct File *out, const char *data, size_t len) {
  memcpy(out->data + out->len, data, len);
  out->len += len;
  return 1;
}

static int HasAppendedMarker(const struct File *file) {
  return strstr(file->data, "# Appended to version file.") != NULL;
}

static void FindInsertionPoint(const struct File *base, size_t *top_end,
                               size_t *bottom_start) {
  const char *marker = strstr(base->data, "DO NOT DELETE");
  const char *line;
  const char *after_line;

  if (!marker) {
    *top_end = base->len;
    *bottom_start = base->len;
    return;
  }

  line = marker;
  while (line > base->data && line[-1] != '\n') {
    line--;
  }
  after_line = marker;
  while (*after_line && *after_line != '\n') {
    after_line++;
  }
  if (*after_line == '\n') {
    after_line++;
  }

  *bottom_start = (size_t)(line - base->data);
  *top_end = (size_t)(after_line - base->data);
}

static int DropLine(const char *line, size_t len) {
  size_t pos = 0;
  while (pos < len && (line[pos] == ' ' || line[pos] == '\t')) {
    pos++;
  }
  if (pos >= len || line[pos] != '#') {
    return 0;
  }
  return pos + 1 >= len || line[pos + 1] == '#' ||
         isspace((unsigned char)line[pos + 1]);
}

static int FilterComments(struct File *file) {
  size_t read = 0;
  size_t write = 0;

  while (read < file->len) {
    size_t line_start = read;
    size_t content_end;
    size_t line_end;

    while (read < file->len && file->data[read] != '\n') {
      read++;
    }
    content_end = read;
    line_end = read < file->len ? read + 1 : read;

    if (!DropLine(file->data + line_start, content_end - line_start)) {
      memmove(file->data + write, file->data + line_start,
              line_end - line_start);
      write += line_end - line_start;
    }
    read = line_end;
  }

  file->len = write;
  return 1;
}

int main(int argc, char **argv) {
  struct File base = {0};
  struct File *ports = NULL;
  struct File out = {0};
  size_t ports_len = 0;
  size_t top_end = 0;
  size_t bottom_start = 0;
  size_t output_len;
  int append_ports = 0;
  int ok = 0;
  int i;

  if (argc < 3) {
    fprintf(stderr,
            "usage: libstdcxx-symbols-assembler OUTPUT BASE [PORT...]\n");
    return 2;
  }

  if (!ReadFile(argv[2], &base)) {
    goto done;
  }

  if (argc > 3) {
    ports = (struct File *)calloc((size_t)(argc - 3), sizeof(struct File));
    if (!ports) {
      PrintErrno("calloc");
      goto done;
    }
  }

  for (i = 3; i < argc; ++i) {
    struct File *port = &ports[i - 3];
    if (!ReadFile(argv[i], port)) {
      goto done;
    }
    ports_len += port->len;
    append_ports = append_ports || HasAppendedMarker(port);
  }

  if (!append_ports && ports_len != 0) {
    FindInsertionPoint(&base, &top_end, &bottom_start);
  }

  output_len = base.len + ports_len + top_end - bottom_start;
  out.data = (char *)malloc(output_len + 1);
  if (!out.data) {
    PrintErrno("malloc");
    goto done;
  }

  if (append_ports || ports_len == 0) {
    Append(&out, base.data, base.len);
    for (i = 3; i < argc; ++i) {
      Append(&out, ports[i - 3].data, ports[i - 3].len);
    }
  } else {
    Append(&out, base.data, top_end);
    for (i = 3; i < argc; ++i) {
      Append(&out, ports[i - 3].data, ports[i - 3].len);
    }
    Append(&out, base.data + bottom_start, base.len - bottom_start);
  }

  out.data[out.len] = '\0';
  ok = FilterComments(&out) && WriteFile(argv[1], &out);

done:
  free(base.data);
  if (ports) {
    for (i = 3; i < argc; ++i) {
      free(ports[i - 3].data);
    }
  }
  free(ports);
  free(out.data);
  return ok ? 0 : 1;
}
