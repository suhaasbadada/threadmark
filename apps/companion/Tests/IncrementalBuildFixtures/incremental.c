/* Synthetic AG complete capture/EOF fixture. No shell or source I/O. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 78 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "index-incremental") ||
        strcmp(argv[4], "alpha") || strcmp(argv[5], "--expected-root") || strcmp(argv[6], "/synthetic/inspection") ||
        strcmp(argv[7], "--expected-root-identity") || strcmp(argv[8], "root-identity") ||
        strcmp(argv[9], "--expected-incarnation") || strlen(argv[10]) != 32 ||
        strcmp(argv[11], "--expected-snapshot") || (strlen(argv[12]) != 64 && strcmp(argv[12], "none")) ||
        strcmp(argv[13], "--expected-sources") || strcmp(argv[14], "a.rs") || getchar() != EOF) return 2;
    for (int i = 0; i < 32; i++) if (argv[10][i] != 'b') return 2;
    if (strcmp(argv[12], "none")) {
        for (int i = 0; i < 64; i++) if (argv[12][i] != 'a') return 2;
    }
    for (int i = 1; i < 64; i++) {
        char expected[32]; snprintf(expected, sizeof(expected), "f%d.rs", i);
        if (strcmp(argv[14+i], expected)) return 2;
    }
    char path[8192];
    if (snprintf(path, sizeof(path), "%s/response.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *input = fopen(path, "rb"); if (!input) return 2;
    char bytes[4096]; size_t count;
    while ((count = fread(bytes, 1, sizeof(bytes), input))) {
        if (fwrite(bytes, 1, count, stdout) != count) { fclose(input); return 2; }
    }
    int failed = ferror(input); fclose(input); return failed ? 2 : 0;
}
