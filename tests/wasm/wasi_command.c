#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    const char *value = getenv("WASI_TEST_VALUE");
    if (argc != 2 || strcmp(argv[1], "hermetic") != 0 || value == NULL) {
        fprintf(stderr, "missing arguments or WASI_TEST_VALUE\n");
        return 1;
    }

    char *buffer = calloc(256, 1);
    if (buffer == NULL) {
        return 2;
    }
    int length = snprintf(buffer, 256, "%s: %s %.2f\n", argv[1], value, 42.25);
    if (length <= 0 || length >= 256) {
        free(buffer);
        return 3;
    }

    FILE *file = fopen("/work/result.txt", "w+");
    if (file == NULL) {
        perror("fopen");
        free(buffer);
        return 4;
    }
    if (fwrite(buffer, 1, (size_t)length, file) != (size_t)length ||
        fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        free(buffer);
        return 5;
    }

    char contents[256] = {0};
    if (fread(contents, 1, (size_t)length, file) != (size_t)length ||
        memcmp(contents, buffer, (size_t)length) != 0) {
        fclose(file);
        free(buffer);
        return 6;
    }
    if (fclose(file) != 0 || fputs(contents, stdout) < 0) {
        free(buffer);
        return 7;
    }
    free(buffer);
    return 0;
}
