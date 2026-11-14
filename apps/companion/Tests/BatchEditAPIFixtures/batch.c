/* Synthetic exact argv and JSON-stdin fixture; no database mutation. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 12 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "context") ||
        strcmp(argv[4], "batch-edit") || strcmp(argv[5], "alpha") ||
        strcmp(argv[6], "--expected-root") || strcmp(argv[7], "/synthetic/inspection") ||
        strcmp(argv[8], "--expected-root-identity") || strcmp(argv[9], "root-identity") ||
        strcmp(argv[10], "--expected-incarnation") || strlen(argv[11]) != 32) return 2;
    char path[8192];
    if (snprintf(path, sizeof(path), "%s/request.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *expected = fopen(path, "rb");
    if (!expected) return 2;
    int actual, wanted; size_t total = 0;
    do {
        actual = getchar(); wanted = fgetc(expected);
        if (actual != wanted || ++total > 65537) { fclose(expected); return 2; }
    } while (actual != EOF);
    fclose(expected);
    if (snprintf(path, sizeof(path), "%s/response.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *response = fopen(path, "rb");
    if (!response) return 2;
    char bytes[4096]; size_t count;
    while ((count = fread(bytes, 1, sizeof(bytes), response))) {
        if (fwrite(bytes, 1, count, stdout) != count) { fclose(response); return 2; }
    }
    int failed = ferror(response); fclose(response); return failed ? 2 : 0;
}
