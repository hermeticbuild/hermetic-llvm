#include <stdio.h>

int thin_lto_answer(void);
int native_answer(void);

int main(void) {
    int result = thin_lto_answer() + native_answer();
    printf("%d\n", result);
    return result != 42;
}
