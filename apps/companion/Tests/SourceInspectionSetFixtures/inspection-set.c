/* Synthetic exact AQ argv, JSON-only stdin and EOF / hostile stdout fixture. */
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 81 || strcmp(argv[1], "--data-dir") || strcmp(argv[3], "source") ||
        strcmp(argv[4], "inspect-set") || strcmp(argv[5], "alpha") ||
        strcmp(argv[6], "--radius") || strcmp(argv[7], "2") ||
        strcmp(argv[8], "--expected-root") || strcmp(argv[9], "/synthetic/inspection") ||
        strcmp(argv[10], "--expected-root-identity") || strcmp(argv[11], "root-identity") ||
        strcmp(argv[12], "--expected-incarnation") || strcmp(argv[13], "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") ||
        strcmp(argv[14], "--expected-snapshot") || strcmp(argv[15], "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") ||
        strcmp(argv[16], "--expected-sources") || strcmp(argv[17], "a.rs")) return 2;
    for (int i = 1; i < 64; i++) {
        char expected[32]; snprintf(expected, sizeof(expected), "f%d.rs", i);
        if (strcmp(argv[17+i], expected)) return 2;
    }
    char input[65537]; size_t length = fread(input, 1, sizeof(input), stdin);
    if (ferror(stdin) || !feof(stdin) || length > 65536) return 2;
    input[length] = 0;
    const char *expected = "{\"anchors\":[{\"line\":3,\"path\":\"a.rs\",\"source_hash\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"},{\"line\":4,\"path\":\"a.rs\",\"source_hash\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}],\"version\":\"source-inspection-set-v1\"}";
    if (length != strlen(expected) || memcmp(input, expected, length)) return 2;
    char path[8192];
    if (snprintf(path, sizeof(path), "%s/response.json", argv[2]) >= (int)sizeof(path)) return 2;
    FILE *response = fopen(path, "rb");
    if (!response) return 2;
    char bytes[4096]; size_t count;
    while ((count = fread(bytes, 1, sizeof(bytes), response))) {
        if (fwrite(bytes, 1, count, stdout) != count) { fclose(response); return 2; }
    }
    int failed = ferror(response); fclose(response); return failed ? 2 : 0;
}
