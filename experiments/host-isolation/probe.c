/* Synthetic fixture only: no host, DNS, real config, or external addresses. */
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

static int denied_file(const char *path, int flags) {
    int fd = open(path, flags);
    if (fd >= 0) { close(fd); return 0; }
    return errno == EPERM || errno == EACCES;
}

static int connect_port(const char *port, int allowed, int family) {
    int fd = socket(family, SOCK_STREAM, 0);
    if (fd < 0) return 0; /* Socket creation denial is not a positive control. */
    struct sockaddr_storage storage = {0};
    socklen_t length;
    if (family == AF_INET) {
        struct sockaddr_in *address = (struct sockaddr_in *)&storage;
        address->sin_family = AF_INET;
        address->sin_port = htons((unsigned short)atoi(port));
        address->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        length = sizeof(*address);
    } else {
        struct sockaddr_in6 *address = (struct sockaddr_in6 *)&storage;
        address->sin6_family = AF_INET6;
        address->sin6_port = htons((unsigned short)atoi(port));
        address->sin6_addr = in6addr_loopback;
        length = sizeof(*address);
    }
    int result = connect(fd, (struct sockaddr *)&storage, length);
    int error = errno;
    close(fd);
    return allowed ? result == 0 : result == -1 && (error == EPERM || error == EACCES);
}

static int denied_udp(const char *port) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return errno == EPERM || errno == EACCES;
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_port = htons((unsigned short)atoi(port));
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    int result = (int)sendto(fd, "synthetic", 9, 0,
                            (struct sockaddr *)&address, sizeof(address));
    int error = errno;
    close(fd);
    return result == -1 && (error == EPERM || error == EACCES);
}

static int checks(char **argv) {
    int fd = open("state-canary", O_RDWR | O_CREAT | O_TRUNC, 0600);
    char data[4] = {0};
    if (fd < 0 || write(fd, "own", 3) != 3 || lseek(fd, 0, SEEK_SET) != 0 ||
        read(fd, data, 3) != 3 || strcmp(data, "own") != 0) return 10;
    close(fd);
    if (!denied_file(argv[1], O_RDONLY)) return 11;
    if (!denied_file(argv[1], O_WRONLY | O_TRUNC)) return 12;
    if (strcmp(argv[2], "filesystem") != 0) {
        if (!connect_port(argv[2], 1, AF_INET)) return 13;
        if (!connect_port(argv[3], 0, AF_INET)) return 14;
        if (!connect_port(argv[2], 1, AF_INET6)) return 17;
        if (!connect_port(argv[3], 0, AF_INET6)) return 18;
        if (!denied_udp(argv[2])) return 19;
    }
    /* The symlink is experiment-owned and targets only the outside canary. */
    if (!denied_file("outside-link", O_RDONLY)) return 15;
    if (!denied_file("outside-link", O_WRONLY | O_TRUNC)) return 16;
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) return 2;
    int result = checks(argv);
    if (result) return result;
    pid_t child = fork();
    if (child < 0) return 20;
    if (child == 0) {
        result = checks(argv);
        if (result) _exit(result);
        /* Even an existing system executable must not be admitted. */
        char *const args[] = {"/bin/sh", "-c", "exit 99", NULL};
        execv(args[0], args);
        _exit(errno == EPERM || errno == EACCES ? 0 : 21);
    }
    int status = 0;
    if (waitpid(child, &status, 0) != child || !WIFEXITED(status) ||
        WEXITSTATUS(status) != 0) return 22;
    puts("synthetic-guard-ok");
    return 0;
}
