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

int main(int argc, char **argv) {
    const char *clangxx = required_env("LLVM_CLANGXX");

    char **clang_args = (char **)calloc((size_t)argc + 1, sizeof(char *));
    if (clang_args == NULL) {
        fprintf(stderr, "link-wrapper: failed to allocate clang argv\n");
        return 127;
    }

    clang_args[0] = (char *)clangxx;
    for (int i = 1; i < argc; ++i) {
        clang_args[i] = argv[i];
    }
    clang_args[argc] = NULL;

    int status = run_process(clang_args);
    free(clang_args);
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

    return run_process(dsym_args);
}
