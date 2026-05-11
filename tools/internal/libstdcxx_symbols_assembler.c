#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct Buffer {
  char *data;
  size_t len;
  size_t cap;
};

static void PrintErrno(const char *path) {
  fprintf(stderr, "libstdcxx-symbols-assembler: %s: %s\n", path,
          strerror(errno));
}

static int Reserve(struct Buffer *buffer, size_t extra) {
  size_t needed;
  char *new_data;
  size_t new_cap;

  if (extra > ((size_t)-1) - buffer->len) {
    fprintf(stderr, "libstdcxx-symbols-assembler: allocation overflow\n");
    return 0;
  }

  needed = buffer->len + extra;
  if (needed <= buffer->cap) {
    return 1;
  }

  new_cap = buffer->cap ? buffer->cap : 4096;
  while (new_cap < needed) {
    if (new_cap > ((size_t)-1) / 2) {
      fprintf(stderr, "libstdcxx-symbols-assembler: allocation overflow\n");
      return 0;
    }
    new_cap *= 2;
  }

  new_data = (char *)realloc(buffer->data, new_cap);
  if (!new_data) {
    PrintErrno("realloc");
    return 0;
  }
  buffer->data = new_data;
  buffer->cap = new_cap;
  return 1;
}

static int AppendBytes(struct Buffer *buffer, const char *data, size_t len) {
  if (len == 0) {
    return 1;
  }
  if (!Reserve(buffer, len)) {
    return 0;
  }
  memcpy(buffer->data + buffer->len, data, len);
  buffer->len += len;
  return 1;
}

static int ReadFile(const char *path, struct Buffer *out) {
  FILE *file;
  char chunk[8192];
  size_t n;

  file = fopen(path, "rb");
  if (!file) {
    PrintErrno(path);
    return 0;
  }

  while ((n = fread(chunk, 1, sizeof(chunk), file)) != 0) {
    if (!AppendBytes(out, chunk, n)) {
      fclose(file);
      return 0;
    }
  }

  if (ferror(file)) {
    PrintErrno(path);
    fclose(file);
    return 0;
  }

  if (fclose(file) != 0) {
    PrintErrno(path);
    return 0;
  }
  return 1;
}

static int WriteFile(const char *path, const struct Buffer *buffer) {
  FILE *file = fopen(path, "wb");
  if (!file) {
    PrintErrno(path);
    return 0;
  }
  if (buffer->len && fwrite(buffer->data, 1, buffer->len, file) != buffer->len) {
    PrintErrno(path);
    fclose(file);
    return 0;
  }
  if (fclose(file) != 0) {
    PrintErrno(path);
    return 0;
  }
  return 1;
}

static int ContainsAppendedMarker(const struct Buffer *buffer) {
  const char marker[] = "# Appended to version file.";
  size_t marker_len = sizeof(marker) - 1;
  size_t pos = 0;

  while (pos < buffer->len) {
    size_t line_start = pos;
    while (pos < buffer->len && buffer->data[pos] != '\n') {
      pos++;
    }
    if (pos - line_start >= marker_len &&
        memcmp(buffer->data + line_start, marker, marker_len) == 0) {
      return 1;
    }
    if (pos < buffer->len) {
      pos++;
    }
  }
  return 0;
}

static int FindInsertionPoint(const struct Buffer *buffer, size_t *top_end,
                              size_t *bottom_start) {
  const char marker[] = "DO NOT DELETE";
  size_t marker_len = sizeof(marker) - 1;
  size_t pos = 0;

  while (pos < buffer->len) {
    size_t line_start = pos;
    size_t line_end;
    while (pos < buffer->len && buffer->data[pos] != '\n') {
      pos++;
    }
    line_end = pos;
    if (line_end - line_start >= marker_len) {
      size_t i;
      for (i = line_start; i + marker_len <= line_end; ++i) {
        if (memcmp(buffer->data + i, marker, marker_len) == 0) {
          *bottom_start = line_start;
          *top_end = pos < buffer->len ? pos + 1 : pos;
          return 1;
        }
      }
    }
    if (pos < buffer->len) {
      pos++;
    }
  }

  *bottom_start = buffer->len;
  *top_end = buffer->len;
  return 0;
}

static int ShouldDropLine(const char *line, size_t len) {
  size_t pos = 0;
  char next;

  while (pos < len && (line[pos] == ' ' || line[pos] == '\t')) {
    pos++;
  }

  if (pos >= len || line[pos] != '#') {
    return 0;
  }

  if (pos + 1 >= len) {
    return 1;
  }

  next = line[pos + 1];
  return next == '#' || isspace((unsigned char)next);
}

static int FilterComments(const struct Buffer *input, struct Buffer *output) {
  size_t pos = 0;
  while (pos < input->len) {
    size_t line_start = pos;
    size_t line_content_end;
    size_t line_end;

    while (pos < input->len && input->data[pos] != '\n') {
      pos++;
    }

    line_content_end = pos;
    line_end = pos < input->len ? pos + 1 : pos;
    if (!ShouldDropLine(input->data + line_start,
                        line_content_end - line_start)) {
      if (!AppendBytes(output, input->data + line_start, line_end - line_start)) {
        return 0;
      }
    }

    pos = line_end;
  }
  return 1;
}

static void FreeBuffer(struct Buffer *buffer) {
  free(buffer->data);
  buffer->data = NULL;
  buffer->len = 0;
  buffer->cap = 0;
}

int main(int argc, char **argv) {
  struct Buffer base = {0};
  struct Buffer ports = {0};
  struct Buffer combined = {0};
  struct Buffer filtered = {0};
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

  for (i = 3; i < argc; ++i) {
    struct Buffer port = {0};
    if (!ReadFile(argv[i], &port)) {
      FreeBuffer(&port);
      goto done;
    }
    if (ContainsAppendedMarker(&port)) {
      append_ports = 1;
    }
    if (!AppendBytes(&ports, port.data, port.len)) {
      FreeBuffer(&port);
      goto done;
    }
    FreeBuffer(&port);
  }

  if (append_ports || ports.len == 0) {
    if (!AppendBytes(&combined, base.data, base.len) ||
        !AppendBytes(&combined, ports.data, ports.len)) {
      goto done;
    }
  } else {
    size_t top_end;
    size_t bottom_start;
    FindInsertionPoint(&base, &top_end, &bottom_start);
    if (!AppendBytes(&combined, base.data, top_end) ||
        !AppendBytes(&combined, ports.data, ports.len) ||
        !AppendBytes(&combined, base.data + bottom_start,
                     base.len - bottom_start)) {
      goto done;
    }
  }

  if (!FilterComments(&combined, &filtered) || !WriteFile(argv[1], &filtered)) {
    goto done;
  }

  ok = 1;

done:
  FreeBuffer(&base);
  FreeBuffer(&ports);
  FreeBuffer(&combined);
  FreeBuffer(&filtered);
  return ok ? 0 : 1;
}
