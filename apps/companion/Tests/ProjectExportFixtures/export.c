/* Synthetic hostile stdout fixture; never a production executable. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 17 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "project") ||
        strcmp(argv[4], "export") || strcmp(argv[5], "alpha") ||
        strcmp(argv[6], "--confirm-export-local-content") || strcmp(argv[7], "--expected-root") ||
        strcmp(argv[9], "--expected-root-identity") || strcmp(argv[10], "1:2") ||
        strcmp(argv[11], "--expected-incarnation") || strcmp(argv[12], "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") ||
        strcmp(argv[13], "--expected-snapshot") || strcmp(argv[14], "none") ||
        strcmp(argv[15], "--expected-sources") || strcmp(argv[16], "a.rs") || getchar() != EOF) return 2;
    char path[8192];
    if (snprintf(path, sizeof(path), "%s/response.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *input = fopen(path, "rb");
    if (!input) return 2;
    char bytes[4096];
    size_t count;
    while ((count = fread(bytes, 1, sizeof(bytes), input))) {
        if (fwrite(bytes, 1, count, stdout) != count) { fclose(input); return 2; }
    }
    int failed = ferror(input);
    fclose(input);
    return failed ? 2 : 0;
}
