#include "shared_library_probe.h"

int main(void) {
    return shared_answer() == 42 ? 0 : 1;
}
