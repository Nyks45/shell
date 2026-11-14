// Fast native boot launcher for Caelestia's Nebula login manager.
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
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

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

static void load_locale_file(const char* path) {
    FILE* f = fopen(path, "r");
    if (!f)
        return;
    char line[256];
    while (fgets(line, sizeof line, f)) {
        char* p = line;
        while (*p == ' ' || *p == '\t')
            p++;
        if (*p == '#' || *p == '\n' || *p == '\0')
            continue;
        char* eq = strchr(p, '=');
        if (!eq)
            continue;
        *eq = '\0';
        char* val = eq + 1;
        size_t vlen = strlen(val);
        while (vlen > 0 && (val[vlen - 1] == '\n' || val[vlen - 1] == '\r' || isspace((unsigned char)val[vlen - 1])))
            val[--vlen] = '\0';
        if (vlen >= 2 && ((val[0] == '"' && val[vlen - 1] == '"') || (val[0] == '\'' && val[vlen - 1] == '\''))) {
            val[vlen - 1] = '\0';
            val++;
        }
        setenv(p, val, 0);
    }
    fclose(f);
}

static bool dir_exists(const char* path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

static bool has_colon_entry(const char* list, const char* entry) {
    if (!list || !*list)
        return false;
    size_t elen = strlen(entry);
    const char* p = list;
    while (*p) {
        const char* colon = strchr(p, ':');
        size_t len = colon ? (size_t)(colon - p) : strlen(p);
        if (len == elen && strncmp(p, entry, len) == 0)
            return true;
        if (!colon)
            break;
        p = colon + 1;
    }
    return false;
}

static void append_colon_entry(char* buf, size_t cap, const char* entry) {
    if (has_colon_entry(buf, entry))
        return;
    size_t cur = strlen(buf);
    if (cur > 0) {
        if (cur + 1 + strlen(entry) + 1 >= cap)
            return;
        buf[cur++] = ':';
        buf[cur] = '\0';
    }
    snprintf(buf + cur, cap - cur, "%s", entry);
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
    if (argc > 1) {
        execv(SESSION_HELPER, argv);
        perror("execv caelestia-session");
        return 127;
    }

    const char* home = getenv("HOME");
    if (!home || !*home)
        home = "/home/hakan";

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

    if (!getenv("LANG") || !*getenv("LANG")) {
        char user_loc[1024];
        const char* cfg = getenv("XDG_CONFIG_HOME");
        if (cfg && *cfg)
            snprintf(user_loc, sizeof user_loc, "%s/locale.conf", cfg);
        else
            snprintf(user_loc, sizeof user_loc, "%s/.config/locale.conf", home);
        if (access(user_loc, R_OK) == 0)
            load_locale_file(user_loc);
        else
            load_locale_file("/etc/locale.conf");
        setenv("LANG", "C.UTF-8", 0);
    }

    // Replicate /etc/profile + flatpak/perlbin/vapoursynth without forking `/bin/sh -l`.
    char pathbuf[4096];
    char local_bin[1024];
    snprintf(local_bin, sizeof local_bin, "%s/.local/bin", home);
    const char* orig_path = getenv("PATH");
    snprintf(pathbuf, sizeof pathbuf, "%s", local_bin);
    if (orig_path && *orig_path) {
        char tmp[4096];
        snprintf(tmp, sizeof tmp, "%s", orig_path);
        char* save = NULL;
        for (char* tok = strtok_r(tmp, ":", &save); tok; tok = strtok_r(NULL, ":", &save))
            append_colon_entry(pathbuf, sizeof pathbuf, tok);
    }
    append_colon_entry(pathbuf, sizeof pathbuf, "/usr/local/sbin");
    append_colon_entry(pathbuf, sizeof pathbuf, "/usr/local/bin");
    append_colon_entry(pathbuf, sizeof pathbuf, "/usr/bin");
    if (dir_exists("/usr/bin/site_perl"))
        append_colon_entry(pathbuf, sizeof pathbuf, "/usr/bin/site_perl");
    if (dir_exists("/usr/bin/vendor_perl"))
        append_colon_entry(pathbuf, sizeof pathbuf, "/usr/bin/vendor_perl");
    if (dir_exists("/usr/bin/core_perl"))
        append_colon_entry(pathbuf, sizeof pathbuf, "/usr/bin/core_perl");
    setenv("PATH", pathbuf, 1);

    char xdgbuf[4096] = "";
    char user_fp[1024];
    const char* xdg_data_home = getenv("XDG_DATA_HOME");
    if (xdg_data_home && *xdg_data_home)
        snprintf(user_fp, sizeof user_fp, "%s/flatpak/exports/share", xdg_data_home);
    else
        snprintf(user_fp, sizeof user_fp, "%s/.local/share/flatpak/exports/share", home);
    append_colon_entry(xdgbuf, sizeof xdgbuf, user_fp);
    append_colon_entry(xdgbuf, sizeof xdgbuf, "/var/lib/flatpak/exports/share");
    const char* orig_xdg = getenv("XDG_DATA_DIRS");
    if (!orig_xdg || !*orig_xdg)
        orig_xdg = "/usr/local/share/:/usr/share/";
    char xtmp[4096];
    snprintf(xtmp, sizeof xtmp, "%s", orig_xdg);
    char* xsave = NULL;
    for (char* tok = strtok_r(xtmp, ":", &xsave); tok; tok = strtok_r(NULL, ":", &xsave))
        append_colon_entry(xdgbuf, sizeof xdgbuf, tok);
    setenv("XDG_DATA_DIRS", xdgbuf, 1);

    if (access("/usr/lib/python3.14/site-packages/vapoursynth/libvsscript.so", R_OK) == 0)
        setenv("VSSCRIPT_PATH", "/usr/lib/python3.14/site-packages/vapoursynth/libvsscript.so", 0);

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

    const char* locked_cmd = access(BOOT_SPLASH, X_OK) == 0
        ? BOOT_SPLASH " & exec qs -c caelestia -n"
        : "qs -c caelestia -n";

    char* const exec_args[] = {
        (char*)START_HYPRLAND,
        (char*)"--",
        (char*)"--locked-cmd",
        (char*)locked_cmd,
        NULL,
    };
    execv(START_HYPRLAND, exec_args);
    perror("execv start-hyprland");
    trigger_plymouth_handoff();
    execv(SESSION_HELPER, argv);
    return 127;
}
