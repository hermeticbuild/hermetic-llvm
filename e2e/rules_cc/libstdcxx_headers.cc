#include <algorithm>
#include <any>
#include <array>
#include <atomic>
#include <charconv>
#include <chrono>
#include <complex>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <exception>
#include <forward_list>
#include <fstream>
#include <functional>
#include <future>
#include <iomanip>
#include <ios>
#include <iostream>
#include <iterator>
#include <limits>
#include <list>
#include <locale>
#include <map>
#include <memory>
#include <mutex>
#include <numeric>
#include <optional>
#include <queue>
#include <random>
#include <regex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <thread>
#include <tuple>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <variant>
#include <vector>

#include <bits/c++config.h>

#ifndef _GLIBCXX_RELEASE
#error "_GLIBCXX_RELEASE is required for libstdc++ version-gated smoke coverage"
#endif

#if _GLIBCXX_RELEASE < 8
#error "libstdc++ header smoke expects GCC 8 or newer"
#endif

#include <filesystem>
#define HERMETIC_LLVM_HAS_FILESYSTEM 1
#if _GLIBCXX_RELEASE >= 9
#include <bit>
#include <execution>
#include <memory_resource>
#include <version>
#endif

#if _GLIBCXX_RELEASE >= 10
#include <concepts>
#include <coroutine>
#include <numbers>
#include <ranges>
#include <span>
#include <stop_token>
#endif

#if _GLIBCXX_RELEASE >= 11
#include <barrier>
#include <latch>
#include <semaphore>
#include <source_location>
#include <syncstream>
#endif

#if _GLIBCXX_RELEASE >= 12
#include <expected>
#include <spanstream>
#include <stacktrace>
#endif

#if _GLIBCXX_RELEASE >= 13
#include <format>
#include <stdfloat>
#endif

#if _GLIBCXX_RELEASE >= 14
#include <generator>
#include <print>
#include <text_encoding>
#endif

#if _GLIBCXX_RELEASE >= 15
#include <flat_map>
#include <flat_set>
#endif

#if _GLIBCXX_RELEASE >= 16
#include <contracts>
#include <debugging>
#include <inplace_vector>
#include <mdspan>
#include <meta>
#include <simd>
#endif

#if !defined(HERMETIC_LLVM_HAS_FILESYSTEM) && __has_include(<experimental/filesystem>)
#include <experimental/filesystem>
#define HERMETIC_LLVM_HAS_EXPERIMENTAL_FILESYSTEM 1
#endif

namespace {

template <typename T>
int use_value(const T &value) {
    (void)value;
    return static_cast<int>(sizeof(value));
}

int common_headers() {
    std::vector<int> values = {4, 1, 3, 2};
    std::sort(values.begin(), values.end());

    std::array<char, 4> digits = {'4', '2', '0', '\0'};
    int parsed = 0;
    auto parsed_result = std::from_chars(digits.data(), digits.data() + 3, parsed);
    if (parsed_result.ec != std::errc()) {
        throw std::runtime_error("from_chars failed");
    }

    std::optional<std::string> text = std::string("libstdc++");
    std::variant<int, std::string> variant = *text;
    std::any any_value = values.front();
    std::map<std::string, int> ordered = {{"answer", parsed}};
    std::unordered_map<std::string, int> unordered = {{"size", static_cast<int>(text->size())}};
    std::set<int> set_values(values.begin(), values.end());
    std::unordered_set<int> unordered_values(values.begin(), values.end());
    std::deque<int> deque_values(values.begin(), values.end());
    std::forward_list<int> forward_values(values.begin(), values.end());
    std::list<int> list_values(values.begin(), values.end());
    std::priority_queue<int> queue_values(values.begin(), values.end());
    std::mt19937 rng(1);
    std::ostringstream stream;
    stream << std::quoted(std::string_view(*text));
    std::regex word("[a-z+]+");
    const bool matched = std::regex_match(*text, word);
    std::complex<double> complex_value(1.0, 2.0);
    std::error_code error;
    std::chrono::nanoseconds elapsed(1);
    std::atomic<int> atomic_value(ordered["answer"]);
    std::mutex mutex;
    std::condition_variable condition;
    std::promise<int> promise;
    std::shared_ptr<int> pointer = std::make_shared<int>(parsed);
    auto tuple_value = std::make_tuple(*pointer, matched, stream.str());

    return atomic_value.load() + std::accumulate(values.begin(), values.end(), 0) +
           static_cast<int>(std::get<std::string>(variant).size()) +
           std::any_cast<int>(any_value) + unordered["size"] +
           static_cast<int>(set_values.size() + unordered_values.size() + deque_values.size() +
                            std::distance(forward_values.begin(), forward_values.end()) +
                            list_values.size()) +
           queue_values.top() + static_cast<int>(rng() % 7) + (matched ? 1 : 0) +
           static_cast<int>(complex_value.real()) + error.value() +
           static_cast<int>(elapsed.count()) + use_value(mutex) + use_value(condition) +
           use_value(promise) + std::get<0>(tuple_value) +
           static_cast<int>(std::locale::classic().name().size()) +
           static_cast<int>(std::numeric_limits<unsigned char>::max());
}

int filesystem_headers() {
#if defined(HERMETIC_LLVM_HAS_FILESYSTEM)
    std::filesystem::path path = std::filesystem::path("libstdcxx") / "headers";
    return static_cast<int>(path.filename().string().size());
#elif defined(HERMETIC_LLVM_HAS_EXPERIMENTAL_FILESYSTEM)
    std::experimental::filesystem::path path =
        std::experimental::filesystem::path("libstdcxx") / "headers";
    return static_cast<int>(path.filename().string().size());
#else
    return 0;
#endif
}

int optional_newer_headers() {
    int total = 0;

#if defined(__cpp_lib_bitops)
    total += static_cast<int>(std::popcount(0x2au));
#endif

#if defined(__cpp_lib_memory_resource)
    std::byte buffer[256];
    std::pmr::monotonic_buffer_resource resource(buffer, sizeof(buffer));
    std::pmr::vector<int> pmr_values(&resource);
    pmr_values.push_back(7);
    total += pmr_values.front();
#endif

#if defined(__cpp_lib_span)
    int raw_values[] = {1, 2, 3};
    std::span<int> span_values(raw_values);
    total += span_values[1];
#endif

#if defined(__cpp_lib_ranges)
    std::vector<int> range_values = {3, 1, 2};
    std::ranges::sort(range_values);
    total += range_values.front();
#endif

#if defined(__cpp_lib_expected)
    std::expected<int, std::string> expected = 5;
    total += expected.value();
#endif

#if defined(__cpp_lib_format)
    std::formatter<int, char> formatter;
    total += use_value(formatter);
#endif

#if defined(__cpp_lib_source_location)
    total += static_cast<int>(std::source_location::current().line() > 0);
#endif

#if defined(__cpp_lib_spanstream)
    char input[] = "9";
    std::ispanstream span_stream(std::span<char>(input, 1));
    int parsed = 0;
    span_stream >> parsed;
    total += parsed;
#endif

#if defined(__cpp_lib_syncbuf)
    std::ostringstream sink;
    std::osyncstream sync_stream(sink);
    sync_stream << "sync";
    total += 1;
#endif

    return total;
}

}  // namespace

int main() {
    const int total = common_headers() + filesystem_headers() + optional_newer_headers();
    return total > 0 ? 0 : 1;
}
