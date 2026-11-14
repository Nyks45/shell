// Socket-activated root helper that runs `plymouth deactivate` only at the moment
// Hyprland actually takes over DRM master, avoiding a static frozen splash during
// session setup and dynamic linker/config startup.

#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

#define SD_LISTEN_FDS_START 3

int main(void) {
    const char* nfds = getenv("LISTEN_FDS");
    if (!nfds || atoi(nfds) < 1)
        return 1;

    int lfd = SD_LISTEN_FDS_START;
    struct pollfd lpfd = {.fd = lfd, .events = POLLIN};
    if (poll(&lpfd, 1, 5000) <= 0)
        return 0;

    int cfd = accept4(lfd, NULL, NULL, SOCK_CLOEXEC);
    if (cfd < 0)
        return 1;

    struct pollfd cpfd = {.fd = cfd, .events = POLLIN};
    if (poll(&cpfd, 1, 1000) > 0) {
        char req = 0;
        (void)read(cfd, &req, 1);
    }

    pid_t pid = fork();
    if (pid == 0) {
        char* const args[] = {(char*)"/usr/bin/plymouth", (char*)"deactivate", NULL};
        execv("/usr/bin/plymouth", args);
        _exit(127);
    }
    if (pid > 0) {
        int status = 0;
        while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
    }

    char ack = 'K';
    (void)write(cfd, &ack, 1);
    close(cfd);
    return 0;
}
