// Exercises the paths that need a single unwinder in the process: C cleanups
// run through __gcc_personality_v0 while a C++ exception passes through C
// frames, pthread_exit's forced unwind runs C++ destructors, and exceptions
// cross threads. glibc unwinds pthread_exit with the libgcc_s.so.1 it loads by
// name, so any other unwinder in the process is a second one.

#include <pthread.h>

#include <cstdio>
#include <exception>
#include <stdexcept>
#include <string>
#include <thread>

#include <unwind.h>

// LLVM libunwind's public API. GCC's unwinder does not define it.
extern "C" int unw_getcontext(void*) __attribute__((weak));

extern "C" int run_with_cleanup(void (*fn)(void), int* cleaned);

namespace {

int failures = 0;

void check(bool ok, const char* what) {
  if (!ok) {
    std::fprintf(stderr, "FAIL: %s\n", what);
    ++failures;
  }
}

void throw_runtime_error() { throw std::runtime_error("through C"); }

int destructor_runs = 0;

struct CountDestruction {
  ~CountDestruction() { ++destructor_runs; }
};

void* exit_from_thread(void*) {
  CountDestruction counted;
  pthread_exit(nullptr);
}

_Unwind_Reason_Code count_frame(_Unwind_Context*, void* frames) {
  ++*static_cast<int*>(frames);
  return _URC_NO_REASON;
}

}  // namespace

int main() {
  check(&unw_getcontext == nullptr, "LLVM libunwind is linked");

  int cleaned = 0;
  try {
    run_with_cleanup(throw_runtime_error, &cleaned);
    check(false, "exception not propagated through C frames");
  } catch (const std::runtime_error& e) {
    check(std::string(e.what()) == "through C", "wrong exception caught");
  }
  check(cleaned == 1, "C cleanup did not run during unwinding");

  pthread_t thread;
  check(pthread_create(&thread, nullptr, exit_from_thread, nullptr) == 0, "pthread_create failed");
  pthread_join(thread, nullptr);
  check(destructor_runs == 1, "pthread_exit did not run destructors");

  std::exception_ptr from_thread;
  std::thread([&] {
    try {
      throw std::logic_error("from thread");
    } catch (...) {
      from_thread = std::current_exception();
    }
  }).join();
  try {
    std::rethrow_exception(from_thread);
  } catch (const std::logic_error& e) {
    check(std::string(e.what()) == "from thread", "wrong exception from thread");
  }

  int frames = 0;
  _Unwind_Backtrace(count_frame, &frames);
  check(frames >= 2, "_Unwind_Backtrace found no caller frames");

  return failures == 0 ? 0 : 1;
}
