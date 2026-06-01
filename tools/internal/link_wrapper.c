#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <process.h>
#include <windows.h>
#else
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

#define STRIP_DEBUG_SYMBOLS_ARG "LLVM_STRIP_DEBUG_SYMBOLS"

typedef struct {
    char **clang_args;
    size_t clang_arg_count;
    size_t clang_arg_capacity;
    int strip_debug_symbols;
} parsed_args;

static int error(const char *message) {
    fprintf(stderr, "link-wrapper: %s\n", message);
    return 127;
}

static int error_errno(const char *prefix, const char *path) {
    if (path != NULL) {
        fprintf(stderr, "link-wrapper: %s %s: %s\n", prefix, path, strerror(errno));
    } else {
        fprintf(stderr, "link-wrapper: %s: %s\n", prefix, strerror(errno));
    }
    return 127;
}

static char *dup_string(const char *value) {
    size_t len = strlen(value);
    char *copy = (char *)malloc(len + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, value, len + 1);
    return copy;
}

static int run_process(char *const args[]) {
#ifdef _WIN32
    int status = _spawnv(_P_WAIT, args[0], (const char *const *)args);
    if (status == -1) {
        fprintf(stderr, "link-wrapper: failed to execute %s: %s\n", args[0], strerror(errno));
        return 127;
    }
    return status;
#else
    pid_t pid = fork();
    if (pid == -1) {
        fprintf(stderr, "link-wrapper: failed to fork for %s: %s\n", args[0], strerror(errno));
        return 127;
    }

    if (pid == 0) {
        execv(args[0], args);
        fprintf(stderr, "link-wrapper: failed to execute %s: %s\n", args[0], strerror(errno));
        _exit(127);
    }

    int status = 0;
    while (1) {
        if (waitpid(pid, &status, 0) != -1) {
            break;
        }
        if (errno == EINTR) {
            continue;
        }
        fprintf(stderr, "link-wrapper: failed to wait for %s: %s\n", args[0], strerror(errno));
        return 127;
    }

    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }
    return 127;
#endif
}

static const char *required_env(const char *name) {
    const char *value = getenv(name);
    if (value == NULL || value[0] == '\0') {
        fprintf(stderr, "link-wrapper: required env var %s is not set\n", name);
        exit(127);
    }
    return value;
}

static const char *temp_dir(void) {
    const char *tmpdir = getenv("TMPDIR");
    if (tmpdir != NULL && tmpdir[0] != '\0') {
        return tmpdir;
    }
#ifdef _WIN32
    tmpdir = getenv("TEMP");
    if (tmpdir != NULL && tmpdir[0] != '\0') {
        return tmpdir;
    }
    return ".";
#else
    return "/tmp";
#endif
}

static int create_temp_response_file(char **temp_path, FILE **out) {
    *temp_path = NULL;
    *out = NULL;

#ifdef _WIN32
    const char *tmpdir = temp_dir();
    if (strlen(tmpdir) >= MAX_PATH) {
        return error("temporary directory path is too long");
    }

    char path_buffer[MAX_PATH];
    if (GetTempFileNameA(tmpdir, "lwp", 0, path_buffer) == 0) {
        fprintf(stderr, "link-wrapper: failed to create temporary response file path: %lu\n", GetLastError());
        return 127;
    }

    FILE *file = fopen(path_buffer, "w");
    if (file == NULL) {
        fprintf(stderr, "link-wrapper: failed to create response file %s: %s\n", path_buffer, strerror(errno));
        remove(path_buffer);
        return 127;
    }

    char *path = dup_string(path_buffer);
    if (path == NULL) {
        fclose(file);
        remove(path_buffer);
        return error("failed to allocate response file path");
    }

    *temp_path = path;
    *out = file;
    return 0;
#else
    const char *tmpdir = temp_dir();
    int needed = snprintf(NULL, 0, "%s/link-wrapper-params.XXXXXX", tmpdir);
    if (needed < 0) {
        return error("failed to format response file path");
    }

    char *path = (char *)malloc((size_t)needed + 1);
    if (path == NULL) {
        return error("failed to allocate response file path");
    }

    snprintf(path, (size_t)needed + 1, "%s/link-wrapper-params.XXXXXX", tmpdir);

    int fd = mkstemp(path);
    if (fd == -1) {
        fprintf(stderr, "link-wrapper: failed to create response file %s: %s\n", path, strerror(errno));
        free(path);
        return 127;
    }

    FILE *file = fdopen(fd, "w");
    if (file == NULL) {
        fprintf(stderr, "link-wrapper: failed to open response file %s: %s\n", path, strerror(errno));
        close(fd);
        remove(path);
        free(path);
        return 127;
    }
#endif

    *temp_path = path;
    *out = file;
    return 0;
}

static void parsed_args_init(parsed_args *args) {
    args->clang_args = NULL;
    args->clang_arg_count = 0;
    args->clang_arg_capacity = 0;
    args->strip_debug_symbols = 0;
}

static void parsed_args_destroy(parsed_args *args) {
    for (size_t i = 0; i < args->clang_arg_count; ++i) {
        free(args->clang_args[i]);
    }
    free(args->clang_args);
}

static int parsed_args_add(parsed_args *args, const char *arg) {
    if (args->clang_arg_count == args->clang_arg_capacity) {
        size_t next_capacity = args->clang_arg_capacity == 0 ? 16 : args->clang_arg_capacity * 2;
        char **next_args = (char **)realloc(args->clang_args, next_capacity * sizeof(char *));
        if (next_args == NULL) {
            return error("failed to allocate clang argv");
        }
        args->clang_args = next_args;
        args->clang_arg_capacity = next_capacity;
    }

    char *copy = dup_string(arg);
    if (copy == NULL) {
        return error("failed to allocate clang arg");
    }
    args->clang_args[args->clang_arg_count++] = copy;
    return 0;
}

static int read_line(FILE *file, char **line, size_t *capacity) {
    if (*line == NULL) {
        *capacity = 256;
        *line = (char *)malloc(*capacity);
        if (*line == NULL) {
            return -1;
        }
    }

    size_t len = 0;
    int ch = 0;
    while ((ch = fgetc(file)) != EOF) {
        if (ch == '\n') {
            break;
        }
        if (len + 1 >= *capacity) {
            size_t next_capacity = *capacity * 2;
            char *next_line = (char *)realloc(*line, next_capacity);
            if (next_line == NULL) {
                return -1;
            }
            *line = next_line;
            *capacity = next_capacity;
        }
        (*line)[len++] = (char)ch;
    }

    if (ferror(file)) {
        return -1;
    }
    if (len == 0 && ch == EOF) {
        return 0;
    }

    (*line)[len] = '\0';
    return 1;
}

static char *unescape_arg(const char *arg) {
    size_t len = strlen(arg);
    char *result = (char *)malloc(len + 1);
    if (result == NULL) {
        return NULL;
    }

    size_t out = 0;
    for (size_t i = 0; i < len; ++i) {
        char ch = arg[i];

        if (ch == '\\' && i + 1 < len) {
            result[out++] = arg[++i];
            continue;
        }

        if (ch == '"' || ch == '\'') {
            char quote = ch;
            ++i;
            while (i != len && arg[i] != quote) {
                if (arg[i] == '\\' && i + 1 < len) {
                    ++i;
                }
                result[out++] = arg[i++];
            }
            if (i == len) {
                break;
            }
            continue;
        }

        result[out++] = ch;
    }

    result[out] = '\0';
    return result;
}

static int process_argument(const char *arg, parsed_args *args);

static int process_response_file(const char *arg, parsed_args *args, int *handled) {
    *handled = 0;

    FILE *file = fopen(arg + 1, "r");
    if (file == NULL) {
        return 0;
    }
    *handled = 1;

    char *line = NULL;
    size_t capacity = 0;
    int line_status = 0;
    while ((line_status = read_line(file, &line, &capacity)) == 1) {
        char *unescaped = unescape_arg(line);
        if (unescaped == NULL) {
            free(line);
            fclose(file);
            return error("failed to allocate response file arg");
        }

        int status = process_argument(unescaped, args);
        free(unescaped);
        if (status != 0) {
            free(line);
            fclose(file);
            return status;
        }
    }

    free(line);
    if (line_status == -1) {
        int saved_errno = errno;
        fclose(file);
        errno = saved_errno;
        return error_errno("failed to read response file", arg + 1);
    }

    if (fclose(file) != 0) {
        return error_errno("failed to close response file", arg + 1);
    }
    return 0;
}

static int process_argument(const char *arg, parsed_args *args) {
    if (arg[0] == '@' && arg[1] != '\0') {
        int handled = 0;
        int status = process_response_file(arg, args, &handled);
        if (status != 0) {
            return status;
        }
        if (handled) {
            return 0;
        }
    }

    if (strcmp(arg, STRIP_DEBUG_SYMBOLS_ARG) == 0) {
        args->strip_debug_symbols = 1;
        return 0;
    }

    return parsed_args_add(args, arg);
}

static int parse_args(int argc, char **argv, parsed_args *args) {
    for (int i = 1; i < argc; ++i) {
        int status = process_argument(argv[i], args);
        if (status != 0) {
            return status;
        }
    }
    return 0;
}

static int write_response_file(const parsed_args *args, char **response_path) {
    *response_path = NULL;

    FILE *file = NULL;
    int status = create_temp_response_file(response_path, &file);
    if (status != 0) {
        return status;
    }

    for (size_t i = 0; i < args->clang_arg_count; ++i) {
        const char *arg = args->clang_args[i];
        if (fputc('"', file) == EOF) {
            status = error_errno("failed to write response file", *response_path);
            goto fail;
        }
        for (const char *ch = arg; *ch != '\0'; ++ch) {
            if (*ch == '"' || *ch == '\\') {
                if (fputc('\\', file) == EOF) {
                    status = error_errno("failed to write response file", *response_path);
                    goto fail;
                }
            }
            if (fputc(*ch, file) == EOF) {
                status = error_errno("failed to write response file", *response_path);
                goto fail;
            }
        }
        if (fputs("\"\n", file) == EOF) {
            status = error_errno("failed to write response file", *response_path);
            goto fail;
        }
    }

    if (fclose(file) != 0) {
        file = NULL;
        status = error_errno("failed to close response file", *response_path);
        goto fail;
    }

    return 0;

fail:
    if (file != NULL) {
        fclose(file);
    }
    remove(*response_path);
    free(*response_path);
    *response_path = NULL;
    return status;
}

int main(int argc, char **argv) {
    const char *clangxx = required_env("LLVM_CLANGXX");

    parsed_args args;
    parsed_args_init(&args);
    int status = parse_args(argc, argv, &args);
    if (status != 0) {
        parsed_args_destroy(&args);
        return status;
    }

    char *response_path = NULL;
    status = write_response_file(&args, &response_path);
    if (status != 0) {
        parsed_args_destroy(&args);
        return status;
    }

    size_t response_arg_len = strlen(response_path) + 2;
    char *response_arg = (char *)malloc(response_arg_len);
    if (response_arg == NULL) {
        remove(response_path);
        free(response_path);
        parsed_args_destroy(&args);
        return error("failed to allocate response file argument");
    }
    snprintf(response_arg, response_arg_len, "@%s", response_path);

    char *clang_args[] = {
        (char *)clangxx,
        response_arg,
        NULL,
    };

    status = run_process(clang_args);
    remove(response_path);
    free(response_arg);
    free(response_path);
    if (status != 0) {
        parsed_args_destroy(&args);
        return status;
    }

    const char *dsym_path = getenv("LLVM_DSYM_PATH");
    if (dsym_path == NULL || dsym_path[0] == '\0') {
        parsed_args_destroy(&args);
        return 0;
    }

    const char *link_output = required_env("LLVM_LINK_OUTPUT");
    const char *dsymutil = required_env("LLVM_DSYMUTIL");

    char *dsym_args[] = {
        (char *)dsymutil,
        "-o",
        (char *)dsym_path,
        (char *)link_output,
        NULL,
    };

    status = run_process(dsym_args);
    if (status != 0 || !args.strip_debug_symbols) {
        parsed_args_destroy(&args);
        return status;
    }

    const char *strip = required_env("LLVM_STRIP");
    char *strip_args[] = {
        (char *)strip,
        "-S",
        (char *)link_output,
        NULL,
    };

    parsed_args_destroy(&args);
    return run_process(strip_args);
}
