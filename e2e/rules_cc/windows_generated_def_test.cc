extern "C" __declspec(dllimport) int generated_add42(int);

int main() {
    return generated_add42(0) == 42 ? 0 : 1;
}
