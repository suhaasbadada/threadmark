/* Fixed synthetic controls only. Never prints canary bytes or filesystem paths. */
#define _POSIX_C_SOURCE 200809L
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static int denied(int error) { return error == EPERM || error == EACCES; }

static int report(const char *name, int okay) {
    if (!okay) return 1;
    printf("%s:PASS\n", name);
    return 0;
}

static int path_for(char *out, size_t size, const char *root, const char *suffix) {
    int length = snprintf(out, size, "%s/%s", root, suffix);
    return length < 0 || (size_t)length >= size;
}

static int forbidden(const char *root, const char *suffix, const char *name, int writing) {
    char path[4096];
    if (path_for(path, sizeof(path), root, suffix)) return 1;
    int fd = open(path, writing ? O_WRONLY : O_RDONLY);
    int error = errno;
    if (fd >= 0) close(fd);
    return report(name, fd < 0 && denied(error));
}

static int filesystem(const char *root) {
    char path[4096], bytes[32];
    if (path_for(path, sizeof(path), root, "read-canary")) return 1;
    int fd = open(path, O_RDONLY);
    if (fd < 0) return 1;
    ssize_t length = read(fd, bytes, sizeof(bytes));
    close(fd);
    static const char expected[] = "synthetic-unchanged\n";
    if (report("approved-read", length == (ssize_t)(sizeof(expected) - 1) &&
               memcmp(bytes, expected, sizeof(expected) - 1) == 0)) return 1;
    const char *directories[] = {"home", "tmp", "config", "cache", "data", "state"};
    for (size_t i = 0; i < sizeof(directories) / sizeof(directories[0]); ++i) {
        char suffix[128], name[64];
        snprintf(suffix, sizeof(suffix), "state/%s/positive", directories[i]);
        snprintf(name, sizeof(name), "write-%s", directories[i]);
        if (path_for(path, sizeof(path), root, suffix)) return 1;
        fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (fd < 0) return 1;
        int okay = write(fd, expected, sizeof(expected) - 1) == (ssize_t)(sizeof(expected) - 1);
        if (close(fd) != 0) okay = 0;
        if (report(name, okay)) return 1;
    }
    const char *reads[][2] = {{"sibling", "deny-sibling"},
        {"outside/home/.config/opencode/config.json", "deny-home"},
        {"outside/repository/AGENTS.md", "deny-repo"}, {"outside/config/settings.json", "deny-config"},
        {"state/home/outside-link", "deny-symlink-read"}};
    for (size_t i = 0; i < sizeof(reads) / sizeof(reads[0]); ++i)
        if (forbidden(root, reads[i][0], reads[i][1], 0)) return 1;
    const char *writes[][2] = {{"state/home/outside-link", "deny-symlink-write"},
        {"workspace/check", "deny-workspace-write"}, {"probe", "deny-probe-write"},
        {"guard.sb", "deny-policy-write"}, {"config-inventory/settings.json", "deny-inventory-write"}};
    for (size_t i = 0; i < sizeof(writes) / sizeof(writes[0]); ++i)
        if (forbidden(root, writes[i][0], writes[i][1], 1)) return 1;
    return 0;
}

static int network(const char *label, const char *tcp, const char *udp) {
    int family = strcmp(label, "v4") == 0 ? AF_INET : AF_INET6;
    for (int operation = 0; operation < 4; ++operation) {
        int kind = operation == 1 ? SOCK_DGRAM : SOCK_STREAM;
        int fd = socket(family, kind, 0);
        if (fd < 0) return 1; /* Socket creation failure does not prove each operation. */
        struct sockaddr_storage storage;
        memset(&storage, 0, sizeof(storage));
        int port = operation == 0 ? atoi(tcp) : operation == 1 ? atoi(udp) : 0;
        if (port < 0 || port > 65535 || (operation < 2 && port == 0)) { close(fd); return 1; }
        socklen_t length;
        if (family == AF_INET) {
            struct sockaddr_in *address = (struct sockaddr_in *)&storage;
            address->sin_family = AF_INET;
#ifdef __APPLE__
            address->sin_len = sizeof(*address);
#endif
            address->sin_port = htons((unsigned short)port);
            if (inet_pton(AF_INET, "127.0.0.1", &address->sin_addr) != 1) { close(fd); return 1; }
            length = sizeof(*address);
        } else {
            struct sockaddr_in6 *address = (struct sockaddr_in6 *)&storage;
            address->sin6_family = AF_INET6;
#ifdef __APPLE__
            address->sin6_len = sizeof(*address);
#endif
            address->sin6_port = htons((unsigned short)port);
            if (inet_pton(AF_INET6, "::1", &address->sin6_addr) != 1) { close(fd); return 1; }
            length = sizeof(*address);
        }
        int result;
        if (operation == 0) result = connect(fd, (struct sockaddr *)&storage, length);
        else if (operation == 1) result = (int)sendto(fd, "synthetic", 9, 0,
                                                    (struct sockaddr *)&storage, length);
        else if (operation == 2) result = bind(fd, (struct sockaddr *)&storage, length);
        else result = listen(fd, 1);
        int error = errno;
        close(fd);
        const char *names[] = {"connect", "udp", "bind", "listen"};
        char name[64];
        snprintf(name, sizeof(name), "%s-%s", label, names[operation]);
        if (report(name, result == -1 && denied(error))) return 1;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) return 2;
    const char *mode = argv[1], *root = argv[2];
    if (strcmp(mode, "filesystem") == 0 && argc == 3) return filesystem(root);
    if (strcmp(mode, "fork") == 0 && argc == 3) {
        pid_t child = fork();
        int error = errno;
        if (child == 0) _exit(90); /* An unexpected successful fork does no private work. */
        if (child > 0) { int status; (void)waitpid(child, &status, 0); return 1; }
        return report("deny-fork", denied(error));
    }
    char marker[4096];
    if (path_for(marker, sizeof(marker), root, "exec-marker")) return 2;
    if (strcmp(mode, "spawn") == 0 && argc == 3) {
        pid_t child;
        char *arguments[] = {marker, NULL};
        int error = posix_spawn(&child, marker, NULL, NULL, arguments, environ);
        if (error == 0) { int status; (void)waitpid(child, &status, 0); return 1; }
        return report("deny-spawn", denied(error));
    }
    if (strcmp(mode, "exec") == 0 && argc == 3) {
        execl(marker, marker, (char *)NULL);
        return report("deny-exec", denied(errno)); /* ENOEXEC does not pass. */
    }
    if (strcmp(mode, "network-v4") == 0 && argc == 5) return network("v4", argv[3], argv[4]);
    if (strcmp(mode, "network-v6") == 0 && argc == 5) return network("v6", argv[3], argv[4]);
    if (strcmp(mode, "parser") == 0 && argc == 3) {
        char path[4096];
        if (path_for(path, sizeof(path), root, "workspace/parser-ran")) return 2;
        int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (fd >= 0) close(fd);
        puts("unexpected-fixture-execution");
        return 91;
    }
    return 2;
}
