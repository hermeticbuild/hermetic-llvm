#include <cstdio>
#include <cstdlib>
#include <stdexcept>
#include <thread>

extern "C" int exchange_c_tls(int next);

thread_local int cpp_tls = 21;

int main() {
    if (exchange_c_tls(7) != 42) return 1;
    cpp_tls = 9;
    std::thread worker([] {
        if (exchange_c_tls(3) != 42 || cpp_tls != 21) std::abort();
        cpp_tls = 6;
    });
    worker.join();
    if (exchange_c_tls(0) != 7 || cpp_tls != 9) return 2;
    try {
        throw std::runtime_error("Cosmopolitan C and C++ TLS OK");
    } catch (const std::runtime_error &error) {
        std::puts(error.what());
    }
}
