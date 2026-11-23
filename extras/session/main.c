// Fast native boot launcher for Caelestia's login manager.
// Avoids Python + `/bin/sh -l` (~280 ms) on cold Hyprland boots while keeping
// `/usr/lib/caelestia/caelestia-session` for `list`, `set`, and non-Hyprland sessions.

#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <poll.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <termios.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>
#include <pwd.h>

#define HANDOFF_SOCK "/run/caelestia/plymouth-handoff.sock"
#define SESSION_HELPER "/usr/lib/caelestia/caelestia-session"
#define BOOT_SPLASH "/usr/lib/caelestia/caelestia-boot-splash"
#define START_HYPRLAND "/usr/bin/start-hyprland"
#define HYPR_DESKTOP "/usr/share/wayland-sessions/hyprland.desktop"

static bool read_dm_session(const char* home, char* out, size_t cap) {
    char path[1024];
    const char* state = getenv("XDG_STATE_HOME");
    if (state && *state)
        snprintf(path, sizeof path, "%s/caelestia/dm-session", state);
    else
        snprintf(path, sizeof path, "%s/.local/state/caelestia/dm-session", home);

    FILE* f = fopen(path, "r");
    if (!f) {
        out[0] = '\0';
        return false;
    }
    size_t n = fread(out, 1, cap - 1, f);
    fclose(f);
    out[n] = '\0';

    char* start = out;
    while (*start && isspace((unsigned char)*start))
        start++;
    if (start != out)
        memmove(out, start, strlen(start) + 1);
    size_t len = strlen(out);
    while (len > 0 && isspace((unsigned char)out[len - 1]))
        out[--len] = '\0';
    return true;
}

static void trigger_plymouth_handoff(void) {
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0)
        return;
    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    snprintf(addr.sun_path, sizeof addr.sun_path, "%s", HANDOFF_SOCK);
    if (connect(fd, (struct sockaddr*)&addr, sizeof addr) == 0) {
        char req = 'D';
        (void)write(fd, &req, 1);
        struct pollfd pfd = {.fd = fd, .events = POLLIN};
        if (poll(&pfd, 1, 1500) > 0) {
            char ack = 0;
            (void)read(fd, &ack, 1);
        }
    }
    close(fd);
}

int main(int argc, char** argv) {
    // pam_systemd gives a local-seat session an ambient CAP_WAKE_ALARM (systemd >= 254). It is
    // inherited by every program started from the desktop, and bubblewrap (Steam's runtime,
    // Flatpak) refuses to start with any capability while not setuid: "Unexpected capabilities
    // but not setuid". Nothing in the desktop needs it, so the session starts without it.
    prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL, 0, 0, 0);

    // The session runs on tty1, whose foreground process group is Hyprland's (and the shell's
    // and its children's): a Ctrl+C reaching the console (it did from a full-screen RDP session)
    // became SIGINT and ended the session. Nothing reads the console while Hyprland runs: no
    // signal keys on it.
    struct termios tio;
    if (isatty(STDIN_FILENO) && tcgetattr(STDIN_FILENO, &tio) == 0) {
        tio.c_lflag &= ~(tcflag_t)ISIG;
        tcsetattr(STDIN_FILENO, TCSANOW, &tio);
    }

    if (argc > 1) {
        execv(SESSION_HELPER, argv);
        perror("execv caelestia-session");
        return 127;
    }

    const char* home = getenv("HOME");
    if (!home || !*home) {
        const struct passwd* pw = getpwuid(getuid());
        home = pw && pw->pw_dir ? pw->pw_dir : "/";
    }

    char chosen[256] = "";
    read_dm_session(home, chosen, sizeof chosen);

    bool is_default_hypr = (chosen[0] == '\0' || strcmp(chosen, "hyprland.desktop") == 0);
    if (!is_default_hypr || access(START_HYPRLAND, X_OK) != 0 || access(HYPR_DESKTOP, R_OK) != 0) {
        // Non-Hyprland sessions still need Plymouth deactivated before hand-off.
        trigger_plymouth_handoff();
        execv(SESSION_HELPER, argv);
        perror("execv caelestia-session");
        return 127;
    }

    setenv("DESKTOP_SESSION", "hyprland", 1);
    setenv("XDG_SESSION_DESKTOP", "Hyprland", 1);
    setenv("XDG_CURRENT_DESKTOP", "Hyprland", 1);
    setenv("XDG_SESSION_TYPE", "wayland", 1);
    setenv("CAELESTIA_BOOT_LOCK", "1", 1);
    setenv("CAELESTIA_MANAGED_LOCK", "1", 1);
    if (access(HANDOFF_SOCK, F_OK) == 0 && access("/usr/share/caelestia/hyprland-handoff", F_OK) == 0)
        setenv("CAELESTIA_PLYMOUTH_HANDOFF", HANDOFF_SOCK, 1);
    else
        // Stock Hyprland or missing handoff marker: release Plymouth before exec.
        trigger_plymouth_handoff();

    const bool gl_handoff = access("/usr/share/caelestia/hyprland-handoff-gl", F_OK) == 0;
    const char* locked_cmd = (!gl_handoff && access(BOOT_SPLASH, X_OK) == 0)
        ? BOOT_SPLASH " & exec qs -c caelestia -n"
        : "exec qs -c caelestia -n";

    // Through a login shell: the same environment as any other login (/etc/profile and
    // its profile.d, ~/.profile: PATH, locale, flatpak, ...), plus ~/.local/bin first
    char* const exec_args[] = {
        (char*)"/bin/sh",
        (char*)"-l",
        (char*)"-c",
        (char*)"export PATH=\"$HOME/.local/bin:$PATH\"; exec " START_HYPRLAND " -- --locked-cmd \"$1\"",
        (char*)"sh",
        (char*)locked_cmd,
        NULL,
    };
    execv("/bin/sh", exec_args);
    perror("execv sh -l start-hyprland");
    trigger_plymouth_handoff();
    execv(SESSION_HELPER, argv);
    return 127;
}
