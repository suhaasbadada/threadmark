/* Synthetic AK two-list argv/EOF and hostile stdout fixture. No source I/O. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    /* CLI's 145 arguments include --data-dir, but not executable argv[0]. */
    if (argc != 146 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "query-files") ||
        strcmp(argv[4], "alpha") || strcmp(argv[5], "center") || strcmp(argv[6], "--mode") ||
        (strcmp(argv[7], "literal") && strcmp(argv[7], "ranked-any-terms")) ||
        strcmp(argv[8], "--selected-files") || strcmp(argv[73], "--expected-root") ||
        strcmp(argv[74], "/synthetic/inspection") || strcmp(argv[75], "--expected-root-identity") ||
        strcmp(argv[76], "root-identity") || strcmp(argv[77], "--expected-incarnation") ||
        strlen(argv[78]) != 32 || strcmp(argv[79], "--expected-snapshot") || strlen(argv[80]) != 64 ||
        strcmp(argv[81], "--expected-sources") || getchar() != EOF) return 2;
    for (int i = 0; i < 32; i++) if (argv[78][i] != 'b') return 2;
    for (int i = 0; i < 64; i++) if (argv[80][i] != 'a') return 2;
    for (int i = 0; i < 64; i++) {
        char expected[32];
        if (i == 0) snprintf(expected, sizeof(expected), "a.rs");
        else snprintf(expected, sizeof(expected), "f%d.rs", i);
        if (strcmp(argv[9+i], expected) || strcmp(argv[82+i], expected)) return 2;
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
