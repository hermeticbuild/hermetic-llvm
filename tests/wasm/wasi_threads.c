#include <pthread.h>
#include <stdio.h>

static void *set_value(void *argument) {
    int *value = argument;
    *value = 42;
    return argument;
}

int main(void) {
    pthread_t thread;
    int value = 0;
    if (pthread_create(&thread, NULL, set_value, &value) != 0) {
        return 1;
    }
    void *result = NULL;
    if (pthread_join(thread, &result) != 0 || result != &value || value != 42) {
        return 2;
    }
    printf("thread value: %d\n", value);
    return 0;
}
