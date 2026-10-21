#include "windows_msvc_libcxx_behavior_support.h"

#include <atomic>
#include <condition_variable>
#include <cstdlib>
#include <cwchar>
#include <exception>
#include <filesystem>
#include <locale>
#include <mutex>
#include <new>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <typeinfo>

namespace {
std::atomic<unsigned long> allocation_calls{0};

struct Base {
  virtual ~Base() = default;
};

struct Derived final : Base {
  int value = 42;
};
}  // namespace

extern "C" int windows_msvc_assembly_value(void);
extern "C" int windows_msvc_raw_assembly_value(void);
extern "C" int windows_msvc_c_smoke(void);

void* operator new(std::size_t size) {
  allocation_calls.fetch_add(1, std::memory_order_relaxed);
  if (void* allocation = std::malloc(size)) {
    return allocation;
  }
  throw std::bad_alloc();
}

void operator delete(void* allocation) noexcept { std::free(allocation); }

void operator delete(void* allocation, std::size_t) noexcept {
  std::free(allocation);
}

int main() {
  // ISO wide %s consumes a narrow string; native MSVC mode consumes wchar_t*.
  // Pad and align the input so a wrong mode fails without reading past it.
  alignas(wchar_t) const char narrow[8] = "wide";
  wchar_t formatted[16];
  if (std::swprintf(formatted, 16, L"%s:%d", narrow, 42) != 7 ||
      std::wstring(formatted) != L"wide:42") {
    return 8;
  }
  if (windows_msvc_ordinary_add(20, 22) != 42 ||
      windows_msvc_alwayslink_marker() != 1 ||
      windows_msvc_library_filesystem() != 42 ||
      windows_msvc_wide_divide(1, 0, 2) != (1ULL << 63) ||
      windows_msvc_assembly_value() != 42 ||
      windows_msvc_raw_assembly_value() != 42 ||
      windows_msvc_c_smoke() != 42) {
    return 1;
  }

  std::exception_ptr captured;
  try {
    throw std::runtime_error("libc++ exception");
  } catch (...) {
    captured = std::current_exception();
  }
  try {
    std::rethrow_exception(captured);
  } catch (const std::runtime_error& error) {
    if (std::string(error.what()) != "libc++ exception") {
      return 2;
    }
  }

  Derived derived;
  Base* base = &derived;
  if (dynamic_cast<Derived*>(base) != &derived || typeid(*base) != typeid(Derived)) {
    return 3;
  }

  const auto allocations_before = allocation_calls.load(std::memory_order_relaxed);
  int* allocated = new int(42);
  if (*allocated != 42 ||
      allocation_calls.load(std::memory_order_relaxed) <= allocations_before) {
    return 4;
  }
  delete allocated;

  std::stringstream stream;
  stream.imbue(std::locale::classic());
  stream << 40 << ' ' << 2;
  int left = 0;
  int right = 0;
  stream >> left >> right;
  if (left + right != 42) {
    return 5;
  }

  const std::filesystem::path path =
      (std::filesystem::path(L"alpha") / L".." / L"beta").lexically_normal();
  if (path.filename().wstring() != L"beta") {
    return 6;
  }

  std::mutex mutex;
  std::condition_variable condition;
  std::atomic<int> atomic_value{0};
  bool ready = false;
  std::thread worker([&] {
    atomic_value.fetch_add(40);
    {
      std::lock_guard<std::mutex> lock(mutex);
      ready = true;
    }
    condition.notify_one();
  });
  {
    std::unique_lock<std::mutex> lock(mutex);
    condition.wait(lock, [&] { return ready; });
  }
  worker.join();
  atomic_value.fetch_add(2);
  if (atomic_value.load() != 42) {
    return 7;
  }

  return 0;
}
