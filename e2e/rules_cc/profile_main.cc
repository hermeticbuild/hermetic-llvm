#include <cstdio>

namespace {

void function_to_profile() {
    volatile int sum = 0;
    for (int i = 0; i < 100; ++i) {
        sum += i;
    }
    (void)sum;
}

}  // namespace

int main() {
    function_to_profile();
    std::puts("profile runtime exercised");
    return 0;
}
