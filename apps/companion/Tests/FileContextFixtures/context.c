/* Synthetic AM exact argv/EOF/bounded stdin and whole-response fixture. */
#include <stdio.h>
#include <string.h>
static FILE *staged(const char *directory, const char *name) {
    char path[8192];
    if (snprintf(path, sizeof(path), "%s/%s", directory, name) >= (int)sizeof(path)) return NULL;
    return fopen(path, "rb");
}
int main(int argc, char **argv) {
    /* 64 selected + 64 full-policy paths; no original in argv. */
    if (argc != 147 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "context") ||
        strcmp(argv[4], "prepare-files") || strcmp(argv[7], "--mode") ||
        (strcmp(argv[8], "literal") && strcmp(argv[8], "ranked-any-terms")) ||
        strcmp(argv[9], "--selected-files") || strcmp(argv[74], "--expected-root") ||
        strcmp(argv[76], "--expected-root-identity") || strcmp(argv[78], "--expected-incarnation") ||
        strcmp(argv[80], "--expected-snapshot") || strcmp(argv[82], "--expected-sources")) return 2;
    FILE *expected = staged(argv[2], "expected-argv.bin"); if (!expected) return 2;
    for (int i = 1; i < argc; i++) {
        size_t n = strlen(argv[i]);
        for (size_t j = 0; j <= n; j++) {
            if (fgetc(expected) != (unsigned char)argv[i][j]) { fclose(expected); return 2; }
        }
    }
    if (fgetc(expected) != EOF || ferror(expected)) { fclose(expected); return 2; }
    fclose(expected);
    expected = staged(argv[2], "expected-input.bin"); if (!expected) return 2;
    int c, count = 0;
    while ((c = getchar()) != EOF) {
        if (++count > 4096 || !c || c != fgetc(expected)) { fclose(expected); return 2; }
    }
    if (!count || ferror(stdin) || fgetc(expected) != EOF || ferror(expected)) { fclose(expected); return 2; }
    fclose(expected);
    FILE *response = staged(argv[2], "response.json"); if (!response) return 2;
    char bytes[4096]; size_t n;
    while ((n = fread(bytes, 1, sizeof(bytes), response))) {
        if (fwrite(bytes, 1, n, stdout) != n) { fclose(response); return 2; }
    }
    int failed = ferror(response); fclose(response); return failed ? 2 : 0;
}
