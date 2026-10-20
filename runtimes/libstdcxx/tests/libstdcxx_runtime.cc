#include <iostream>
#include <string>
#include <thread>

bool legacy_list_abi_works();

int main() {
    if (!legacy_list_abi_works()) {
        return 1;
    }
    unsigned answer = 0;
    std::thread worker([&answer] {
        try {
            throw std::string(42, 'x');
        } catch (const std::string& value) {
            answer = value.size();
        }
    });
    worker.join();
    std::cout << answer << std::endl;
    return answer == 42 ? 0 : 1;
}
