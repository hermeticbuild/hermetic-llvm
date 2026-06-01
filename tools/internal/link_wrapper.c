#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <process.h>
#else
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

#define STRIP_DEBUG_SYMBOLS_ARG "LLVM_STRIP_DEBUG_SYMBOLS"

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
    do {
        if (waitpid(pid, &status, 0) == -1) {
            if (errno == EINTR) {
                continue;
            }
            fprintf(stderr, "link-wrapper: failed to wait for %s: %s\n", args[0], strerror(errno));
            return 127;
        }
        break;
    } while (1);

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

static int is_strip_debug_symbols_arg(const char *arg) {
    return strcmp(arg, STRIP_DEBUG_SYMBOLS_ARG) == 0;
}

static int line_is_strip_debug_symbols_arg(const char *line) {
    const char *start = line;
    while (*start == ' ' || *start == '\t') {
        ++start;
    }

    size_t len = strlen(start);
    while (len > 0 &&
           (start[len - 1] == '\n' || start[len - 1] == '\r' ||
            start[len - 1] == ' ' || start[len - 1] == '\t')) {
        --len;
    }

    if (len == strlen(STRIP_DEBUG_SYMBOLS_ARG) &&
        strncmp(start, STRIP_DEBUG_SYMBOLS_ARG, len) == 0) {
        return 1;
    }

    if (len == strlen(STRIP_DEBUG_SYMBOLS_ARG) + 2 &&
        ((start[0] == '\'' && start[len - 1] == '\'') ||
         (start[0] == '"' && start[len - 1] == '"')) &&
        strncmp(start + 1, STRIP_DEBUG_SYMBOLS_ARG, len - 2) == 0) {
        return 1;
    }

    return 0;
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

    const char *tmpdir = temp_dir();
    int needed = snprintf(NULL, 0, "%s/link-wrapper.XXXXXX", tmpdir);
    if (needed < 0) {
        return 127;
    }

    char *path = (char *)malloc((size_t)needed + 1);
    if (path == NULL) {
        return 127;
    }

    snprintf(path, (size_t)needed + 1, "%s/link-wrapper.XXXXXX", tmpdir);

#ifdef _WIN32
    errno_t temp_status = _mktemp_s(path, (size_t)needed + 1);
    if (temp_status != 0) {
        fprintf(stderr, "link-wrapper: failed to create temporary response file path: %s\n", strerror(temp_status));
        free(path);
        return 127;
    }

    FILE *file = fopen(path, "w");
    if (file == NULL) {
        fprintf(stderr, "link-wrapper: failed to create response file %s: %s\n", path, strerror(errno));
        free(path);
        return 127;
    }
#else
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

static int filter_response_file(const char *response_path, char **filtered_path, int *strip_debug_symbols) {
    *filtered_path = NULL;

    FILE *in = fopen(response_path, "r");
    if (in == NULL) {
        fprintf(stderr, "link-wrapper: failed to open response file %s: %s\n", response_path, strerror(errno));
        return 127;
    }

    int found = 0;
    char line[8192];
    while (fgets(line, sizeof(line), in) != NULL) {
        if (line_is_strip_debug_symbols_arg(line)) {
            found = 1;
            *strip_debug_symbols = 1;
            break;
        }
    }

    if (ferror(in)) {
        fprintf(stderr, "link-wrapper: failed to read response file %s: %s\n", response_path, strerror(errno));
        fclose(in);
        return 127;
    }

    if (!found) {
        fclose(in);
        return 0;
    }

    rewind(in);
    clearerr(in);

    char *temp_path = NULL;
    FILE *out = NULL;
    if (create_temp_response_file(&temp_path, &out) != 0) {
        fclose(in);
        return 127;
    }

    while (fgets(line, sizeof(line), in) != NULL) {
        if (line_is_strip_debug_symbols_arg(line)) {
            continue;
        }
        if (fputs(line, out) == EOF) {
            fprintf(stderr, "link-wrapper: failed to write response file %s: %s\n", temp_path, strerror(errno));
            fclose(out);
            fclose(in);
            remove(temp_path);
            free(temp_path);
            return 127;
        }
    }

    if (ferror(in)) {
        fprintf(stderr, "link-wrapper: failed to read response file %s: %s\n", response_path, strerror(errno));
        fclose(out);
        fclose(in);
        remove(temp_path);
        free(temp_path);
        return 127;
    }

    if (fclose(out) != 0) {
        fprintf(stderr, "link-wrapper: failed to close response file %s: %s\n", temp_path, strerror(errno));
        fclose(in);
        remove(temp_path);
        free(temp_path);
        return 127;
    }
    fclose(in);

    *filtered_path = temp_path;
    return 0;
}

static void cleanup_temp_files(char **paths, int count) {
    for (int i = 0; i < count; ++i) {
        if (paths[i] != NULL) {
            remove(paths[i]);
            free(paths[i]);
        }
    }
}

int main(int argc, char **argv) {
    const char *clangxx = required_env("LLVM_CLANGXX");
    int strip_debug_symbols = 0;

    char **clang_args = (char **)calloc((size_t)argc + 1, sizeof(char *));
    if (clang_args == NULL) {
        fprintf(stderr, "link-wrapper: failed to allocate clang argv\n");
        return 127;
    }
    char **allocated_args = (char **)calloc((size_t)argc + 1, sizeof(char *));
    char **temp_paths = (char **)calloc((size_t)argc + 1, sizeof(char *));
    if (allocated_args == NULL || temp_paths == NULL) {
        fprintf(stderr, "link-wrapper: failed to allocate response file bookkeeping\n");
        free(clang_args);
        free(allocated_args);
        free(temp_paths);
        return 127;
    }

    clang_args[0] = (char *)clangxx;
    int clang_argc = 1;
    int allocated_arg_count = 0;
    int temp_path_count = 0;
    for (int i = 1; i < argc; ++i) {
        if (is_strip_debug_symbols_arg(argv[i])) {
            strip_debug_symbols = 1;
            continue;
        }

        if (argv[i][0] == '@' && argv[i][1] != '\0') {
            char *filtered_path = NULL;
            int filter_status = filter_response_file(argv[i] + 1, &filtered_path, &strip_debug_symbols);
            if (filter_status != 0) {
                cleanup_temp_files(temp_paths, temp_path_count);
                for (int j = 0; j < allocated_arg_count; ++j) {
                    free(allocated_args[j]);
                }
                free(clang_args);
                free(allocated_args);
                free(temp_paths);
                return filter_status;
            }

            if (filtered_path != NULL) {
                size_t response_arg_len = strlen(filtered_path) + 2;
                char *response_arg = (char *)malloc(response_arg_len);
                if (response_arg == NULL) {
                    fprintf(stderr, "link-wrapper: failed to allocate response file argument\n");
                    free(filtered_path);
                    cleanup_temp_files(temp_paths, temp_path_count);
                    for (int j = 0; j < allocated_arg_count; ++j) {
                        free(allocated_args[j]);
                    }
                    free(clang_args);
                    free(allocated_args);
                    free(temp_paths);
                    return 127;
                }
                snprintf(response_arg, response_arg_len, "@%s", filtered_path);
                allocated_args[allocated_arg_count++] = response_arg;
                temp_paths[temp_path_count++] = filtered_path;
                clang_args[clang_argc++] = response_arg;
                continue;
            }
        }

        clang_args[clang_argc++] = argv[i];
    }
    clang_args[clang_argc] = NULL;

    int status = run_process(clang_args);
    cleanup_temp_files(temp_paths, temp_path_count);
    for (int i = 0; i < allocated_arg_count; ++i) {
        free(allocated_args[i]);
    }
    free(clang_args);
    free(allocated_args);
    free(temp_paths);
    if (status != 0) {
        return status;
    }

    const char *dsym_path = getenv("LLVM_DSYM_PATH");
    if (dsym_path == NULL || dsym_path[0] == '\0') {
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
    if (status != 0 || !strip_debug_symbols) {
        return status;
    }

    const char *strip = required_env("LLVM_STRIP");
    char *strip_args[] = {
        (char *)strip,
        "-S",
        (char *)link_output,
        NULL,
    };

    return run_process(strip_args);
}
