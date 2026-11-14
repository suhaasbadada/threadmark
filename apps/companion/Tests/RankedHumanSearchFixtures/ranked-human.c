/* Synthetic AO exact all-five argv/raw UTF-8/EOF and hostile stdout. No source I/O. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    const char *expected[] = {"context", "search-terms", "alpha", "  ÉCHO \"quoted\" ÉCHO  ",
        "--kinds", "constraint", "correction", "decision", "note", "pitfall",
        "--expected-root", "/synthetic/ranked", "--expected-root-identity", "r1",
        "--expected-incarnation", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"};
    if (argc != 19 || strcmp(argv[1], "--data-dir") || getchar() != EOF) return 2;
    for (int i = 0; i < 16; i++) if (strcmp(argv[i + 3], expected[i])) return 2;
    char path[8192];
    if (snprintf(path, sizeof(path), "%s/response.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *input = fopen(path, "rb"); if (!input) return 2;
    char bytes[4096]; size_t count;
    while ((count = fread(bytes, 1, sizeof(bytes), input))) {
        if (fwrite(bytes, 1, count, stdout) != count) { fclose(input); return 2; }
    }
    int failed = ferror(input); fclose(input); return failed ? 2 : 0;
}
