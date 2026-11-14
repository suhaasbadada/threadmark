/* Synthetic AD argv/EOF and hostile whole-response fixture, never production. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 79 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "project") ||
        strcmp(argv[4], "coverage") || strcmp(argv[5], "alpha") ||
        strcmp(argv[6], "--expected-root") || strcmp(argv[7], "/synthetic/inspection") ||
        strcmp(argv[8], "--expected-root-identity") || strcmp(argv[9], "root-identity") ||
        strcmp(argv[10], "--expected-incarnation") || strlen(argv[11]) != 32 ||
        strcmp(argv[12], "--expected-snapshot") ||
        (strlen(argv[13]) != 64 && strcmp(argv[13], "none")) ||
        strcmp(argv[14], "--expected-sources") || strcmp(argv[15], "a.rs") || getchar() != EOF) return 2;
    for (int i = 1; i < 64; i++) {
        char expected[32]; snprintf(expected, sizeof(expected), "f%d.rs", i);
        if (strcmp(argv[15+i], expected)) return 2;
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
