#define _LARGEFILE64_SOURCE 1

#include <atomic>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <thread>

#include <fcntl.h>
#include <gnu/libc-version.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

namespace {

void marker(const char* text) {
    const size_t size = std::strlen(text);
    if (write(STDOUT_FILENO, text, size) != static_cast<ssize_t>(size)) {
        _Exit(90);
    }
}

struct Lifetime {
    Lifetime() { marker("constructor\n"); }
    ~Lifetime() { marker("destructor\n"); }
} lifetime;

std::atomic<int> tls_destructors{0};
struct ThreadState {
    int value = 7;
    ~ThreadState() {
        ++tls_destructors;
        if (value == 42) {
            marker("main_tls_destructor\n");
        }
    }
};
thread_local ThreadState thread_state;

int fork_state = 0;
void prepare() { fork_state = 1; }
void parent() { fork_state = fork_state == 1 ? 2 : -1; }
void child() { fork_state = fork_state == 1 ? 3 : -1; }

void on_exit() { marker("atexit\n"); }
void on_quick_exit() { marker("quick_exit\n"); }

#define CHECK(expression)                                                       \
    do {                                                                        \
        if (!(expression)) {                                                    \
            std::fprintf(stderr, "%s:%d: %s (errno=%d)\n", __FILE__, __LINE__,   \
                         #expression, errno);                                   \
            return 1;                                                           \
        }                                                                       \
    } while (false)

int check_stat_wrappers() {
    char directory[] = "/tmp/hermetic-glibc-XXXXXX";
    CHECK(mkdtemp(directory) != nullptr);
    const int dir = open(directory, O_RDONLY | O_DIRECTORY);
    CHECK(dir >= 0);
    CHECK(mknodat(dir, "fifo", S_IFIFO | 0600, 0) == 0);
    struct stat status;
    struct stat64 status64;
    CHECK(fstat(dir, &status) == 0 && S_ISDIR(status.st_mode));
    CHECK(fstat64(dir, &status64) == 0 && S_ISDIR(status64.st_mode));
    CHECK(stat(directory, &status) == 0 && S_ISDIR(status.st_mode));
    CHECK(stat64(directory, &status64) == 0 && S_ISDIR(status64.st_mode));
    CHECK(lstat(directory, &status) == 0 && S_ISDIR(status.st_mode));
    CHECK(lstat64(directory, &status64) == 0 && S_ISDIR(status64.st_mode));
    CHECK(fstatat(dir, "fifo", &status, 0) == 0 && S_ISFIFO(status.st_mode));
    CHECK(fstatat64(dir, "fifo", &status64, 0) == 0 && S_ISFIFO(status64.st_mode));
    CHECK(fstatat(dir, "missing", &status, 0) == -1 && errno == ENOENT);
    CHECK(unlinkat(dir, "fifo", 0) == 0);
    CHECK(close(dir) == 0);
    CHECK(rmdir(directory) == 0);
    // mknod has a separate nonshared wrapper from mknodat.
    CHECK(mknod(directory, S_IFIFO | 0600, 0) == 0);
    CHECK(unlink(directory) == 0);
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    std::printf("glibc=%s\n", gnu_get_libc_version());
    std::fflush(stdout);
    CHECK(std::atexit(on_exit) == 0);
    if (argc == 2 && std::strcmp(argv[1], "quick") == 0) {
        CHECK(std::at_quick_exit(on_quick_exit) == 0);
        std::quick_exit(0);
    }
    CHECK(argc == 1);
    CHECK(check_stat_wrappers() == 0);

    thread_state.value = 42;
    std::thread worker([] {
        if (thread_state.value != 7) {
            _Exit(91);
        }
        thread_state.value = 99;
    });
    worker.join();
    CHECK(thread_state.value == 42);
    CHECK(tls_destructors == 1);

    CHECK(pthread_atfork(prepare, parent, child) == 0);
    const pid_t pid = fork();
    CHECK(pid >= 0);
    if (pid == 0) {
        _Exit(fork_state == 3 && thread_state.value == 42 ? 0 : 92);
    }
    CHECK(fork_state == 2);
    int status = 0;
    CHECK(waitpid(pid, &status, 0) == pid);
    CHECK(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    marker("runtime_ok\n");
    return 0;
}
