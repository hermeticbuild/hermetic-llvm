#include <iostream>
#include <string>
#include <thread>

int main() {
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
