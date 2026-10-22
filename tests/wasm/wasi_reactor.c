#include <stdlib.h>
#include <string.h>

static int *counter;

__attribute__((constructor))
static void initialize_counter(void) {
    counter = malloc(sizeof(*counter));
    if (counter != NULL) {
        const int initial_value = 37;
        memcpy(counter, &initial_value, sizeof(*counter));
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
