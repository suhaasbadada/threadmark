/* Synthetic hostile child for native pipe/owner teardown tests, never a backend. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

int main(int argc, char **argv) {
    if (argc < 3) return 2;
    char marker[8192];
    if (snprintf(marker, sizeof(marker), "%s/retained-fixture.pid", argv[2]) >= (int)sizeof(marker)) return 2;
    FILE *file = fopen(marker, "w");
    if (!file) return 2;
    fprintf(file, "%d\n", getpid()); fclose(file);
    const char *mode = strrchr(argv[0], '/'); mode = mode ? mode + 1 : argv[0];
    char input[8192];
    if (!fgets(input, sizeof(input), stdin)) return 2;
    signal(SIGTERM, SIG_IGN);
    if (strstr(mode, "duplicate")) {
        puts("{\"version\":1,\"version\":1,\"event\":\"failure\",\"terminal\":true,\"code\":\"Invalid\",\"delivery\":\"DeliveryNotAttempted\"}");
    } else if (strstr(mode, "oversize")) {
        for (int i = 0; i < 8192; ++i) putchar(' ');
        putchar('\n');
    } else if (strstr(mode, "unknown")) {
        puts("{\"version\":1,\"event\":\"auto-use\",\"terminal\":true,\"delivery\":\"DeliveryNotAttempted\"}");
    } else if (strstr(mode, "partial")) {
        fputs("{\"version\":1", stdout); fflush(stdout); return 0;
    } else if (strstr(mode, "eof")) {
        return 0;
    } else if (strstr(mode, "pipeclose")) {
        close(STDIN_FILENO); close(STDOUT_FILENO);
    } else if (strstr(mode, "idle") || strstr(mode, "deinit")) {
        puts("{\"version\":1,\"event\":\"failure\",\"terminal\":false,\"code\":\"ProviderFailed\",\"delivery\":\"DeliveryNotAttempted\",\"downstream\":\"clipboard-draft-send-execution-not-attempted\",\"revision\":1,\"digest\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}");
    } else if (!strstr(mode, "hold")) {
        puts("not JSON");
    }
    fflush(stdout);
    /* Force the owner's identity-safe SIGKILL escalation and real waitpid. */
    for (;;) pause();
}
