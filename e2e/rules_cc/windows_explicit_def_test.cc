extern "C" __declspec(dllimport) int add42(int);

int main() {
    return add42(0) == 42 ? 0 : 1;
}
