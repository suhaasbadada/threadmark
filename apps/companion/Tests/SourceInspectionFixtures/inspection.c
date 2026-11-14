/* Synthetic closed argv / hostile stdout fixture, never production. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 85 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "source") ||
        strcmp(argv[4], "inspect") || strcmp(argv[5], "alpha") || strcmp(argv[6], "a.rs") ||
        strcmp(argv[7], "3") || strcmp(argv[8], "--radius") || strcmp(argv[9], "2") ||
        strcmp(argv[10], "--expected-source-hash") || strlen(argv[11]) != 64 ||
        strcmp(argv[12], "--expected-root") || strcmp(argv[13], "/synthetic/inspection") ||
        strcmp(argv[14], "--expected-root-identity") || strcmp(argv[15], "root-identity") ||
        strcmp(argv[16], "--expected-incarnation") || strlen(argv[17]) != 32 ||
        strcmp(argv[18], "--expected-snapshot") || strlen(argv[19]) != 64 ||
        strcmp(argv[20], "--expected-sources") || strcmp(argv[21], "a.rs") || getchar() != EOF) return 2;
    for (int i = 1; i < 64; i++) {
        char expected[32]; snprintf(expected, sizeof(expected), "f%d.rs", i);
        if (strcmp(argv[21+i], expected)) return 2;
    }
    char path[8192];
    if (snprintf(path, sizeof(path), "%s/response.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *input = fopen(path, "rb");
    if (!input) return 2;
    char bytes[4096]; size_t count;
    while ((count = fread(bytes, 1, sizeof(bytes), input))) {
        if (fwrite(bytes, 1, count, stdout) != count) { fclose(input); return 2; }
    }
    int failed = ferror(input); fclose(input); return failed ? 2 : 0;
}
