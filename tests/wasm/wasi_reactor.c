#include <stdlib.h>

static int *counter;

__attribute__((constructor))
static void initialize_counter(void) {
    counter = malloc(sizeof(*counter));
    if (counter != NULL) {
        *counter = 37;
    }
}

__attribute__((export_name("add_to_counter")))
int add_to_counter(int delta) {
    if (counter == NULL) {
        return -1;
    }
    *counter += delta;
    return *counter;
}
