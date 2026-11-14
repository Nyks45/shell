// caelestia-boot-splash: the Nebula boot scene as a layer surface, up within a few
// milliseconds of Hyprland starting.
//
// At boot Hyprland starts locked (--locked-cmd) and the shell needs over a second to draw
// the lock screen's first frame. With misc:session_lock_xray Hyprland keeps drawing layer
// surfaces under a lock that has no surface yet, so this fills that time with the picture
// the boot animation (assets/plymouth-nebula) ended on and the lock screen starts with:
// the space colour, the same star field, the black hole with its halo, orbiting dots and
// the loading shape. Same numbers as modules/lock (NebulaTheme, BlackHole, LockStars).
// The lock screen then covers it and the shell ends it (SIGTERM via the pid file); it also
// ends by itself after MAX seconds (argv[1], default 12): it must never outlive the lock.

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-layer-shell-unstable-v1-client-protocol.h"

// NebulaTheme.qml
#define STARS 160
#define RING_DOTS 90
#define RING_TILT 0.32
#define HOLE_SIZE 160.0
#define CENTER_HEIGHT 0.42
#define SPIN_RATE ((0.5 + 9 * 0.45) * 1.6) // BlackHole.spinPhase per second while loading
#define COOKIE_DEG_PER_S 100.0             // LoadingIndicator: 360 degrees in 3.6 s

typedef struct {
    double r, g, b;
} rgb;

static const rgb SPACE = {0x05, 0x05, 0x0F};
static const rgb STAR = {0xE9, 0xE4, 0xFF};
static rgb primary = {0x9B, 0xD0, 0xCC}, tertiary = {0xD5, 0xEF, 0xFF}, inverse = {0x33, 0x67, 0x64};

struct buffer {
    struct wl_buffer* wl;
    uint32_t* px;
    bool busy, full; // full: holds the whole base picture already
};

static struct wl_display* display;
static struct wl_compositor* compositor;
static struct wl_shm* shm;
static struct zwlr_layer_shell_v1* layer_shell;
static struct wl_surface* surface;
static struct zwlr_layer_surface_v1* layer_surface;
static struct buffer buffers[2];
static uint32_t* base; // background, stars and halo: everything that doesn't move
static int width, height;
static bool configured, frame_pending;
static volatile sig_atomic_t running = 1;
static double t0, ring[RING_DOTS], ang0[RING_DOTS];

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

// rand() of BlackHole.qml / LockStars.qml
static double qrand(double seed) {
    double x = sin(seed * 12.9898 + 78.233) * 43758.5453;
    return x - floor(x);
}

static inline void blend(uint32_t* p, rgb c, double a) {
    if (a <= 0)
        return;
    if (a > 1)
        a = 1;
    uint32_t v = *p;
    double r = (v >> 16) & 0xFF, g = (v >> 8) & 0xFF, b = v & 0xFF;
    r += (c.r - r) * a;
    g += (c.g - g) * a;
    b += (c.b - b) * a;
    *p = 0xFF000000u | ((uint32_t)(r + 0.5) << 16) | ((uint32_t)(g + 0.5) << 8) | (uint32_t)(b + 0.5);
}

// An antialiased disc of radius rad at (cx, cy)
static void disc(uint32_t* px, double cx, double cy, double rad, rgb c, double alpha) {
    int x0 = (int)floor(cx - rad - 1), x1 = (int)ceil(cx + rad + 1);
    int y0 = (int)floor(cy - rad - 1), y1 = (int)ceil(cy + rad + 1);
    for (int y = y0 < 0 ? 0 : y0; y <= y1 && y < height; y++)
        for (int x = x0 < 0 ? 0 : x0; x <= x1 && x < width; x++) {
            double d = hypot(x + 0.5 - cx, y + 0.5 - cy);
            double cov = rad - d + 0.5;
            if (cov > 0)
                blend(&px[y * width + x], c, alpha * (cov > 1 ? 1 : cov));
        }
}

static void read_scheme(void) {
    char path[512];
    const char* state = getenv("XDG_STATE_HOME");
    const char* home = getenv("HOME");
    if (state && *state)
        snprintf(path, sizeof path, "%s/caelestia/scheme.json", state);
    else
        snprintf(path, sizeof path, "%s/.local/state/caelestia/scheme.json", home ? home : "");
    FILE* f = fopen(path, "r");
    if (!f)
        return;
    static char buf[32768];
    size_t n = fread(buf, 1, sizeof buf - 1, f);
    fclose(f);
    buf[n] = 0;
    const struct {
        const char* key;
        rgb* out;
    } keys[] = {{"\"primary\"", &primary}, {"\"tertiary\"", &tertiary}, {"\"inversePrimary\"", &inverse}};
    for (size_t i = 0; i < sizeof keys / sizeof *keys; i++) {
        const char* p = strstr(buf, keys[i].key);
        if (!p)
            continue;
        p = strchr(p + strlen(keys[i].key), '"');
        unsigned v;
        if (p && sscanf(p + 1, "%6x", &v) == 1 && strspn(p + 1, "0123456789abcdefABCDEF") >= 6)
            *keys[i].out = (rgb){(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF};
    }
}

static double unit(void) {
    double u = fmin(width / 1920.0, height / 1080.0);
    return fmax(0.65, fmin(1.5, u));
}

static void draw_base(void) {
    const uint32_t bg = 0xFF000000u | ((uint32_t)SPACE.r << 16) | ((uint32_t)SPACE.g << 8) | (uint32_t)SPACE.b;
    for (int i = 0; i < width * height; i++)
        base[i] = bg;
    for (int i = 0; i < STARS; i++) { // LockStars' canvas
        bool bright = qrand(i + 1) > 0.9;
        disc(base, qrand(i + 2) * width, qrand(i + 3) * height, bright ? 1.4 : 0.8, STAR, bright ? 0.6 : 0.25);
    }
    // The halo: primary at 0.32 up to 0.2 of its radius, to nothing at the edge; shown at 0.65
    double cx = width / 2.0, cy = height * CENTER_HEIGHT, hr = HOLE_SIZE * unit() * 1.6;
    for (int y = (int)fmax(0, cy - hr); y < height && y <= cy + hr; y++)
        for (int x = (int)fmax(0, cx - hr); x < width && x <= cx + hr; x++) {
            double t = hypot(x + 0.5 - cx, y + 0.5 - cy) / hr;
            if (t < 1)
                blend(&base[y * width + x], primary, (t <= 0.2 ? 0.32 : 0.32 * (1 - (t - 0.2) / 0.8)) * 0.65);
        }
}

// The part that moves: the dots behind the hole, the hole, the loading shape, the dots in front
static void draw_frame(struct buffer* b, double t, int* bx, int* by, int* bw, int* bh) {
    double cx = width / 2.0, cy = height * CENTER_HEIGHT, R = HOLE_SIZE * unit() / 2;
    double ex = 3.4 * R + 6, ey = fmax(R, 3.4 * R * RING_TILT) + 6;
    int x0 = (int)fmax(0, floor(cx - ex)), x1 = (int)fmin(width, ceil(cx + ex));
    int y0 = (int)fmax(0, floor(cy - ey)), y1 = (int)fmin(height, ceil(cy + ey));
    if (!b->full) {
        memcpy(b->px, base, (size_t)width * (size_t)height * 4);
        b->full = true;
        *bx = 0, *by = 0, *bw = width, *bh = height;
    } else {
        for (int y = y0; y < y1; y++)
            memcpy(&b->px[y * width + x0], &base[y * width + x0], (size_t)(x1 - x0) * 4);
        *bx = x0, *by = y0, *bw = x1 - x0, *bh = y1 - y0;
    }

    double phase = t * SPIN_RATE;
    for (int pass = 0; pass < 2; pass++) { // 0: behind the hole, 1: in front
        if (pass == 1) {
            // holeCircle: black, with a 2 px border (inversePrimary at 0.75) inside its edge
            for (int y = (int)floor(cy - R - 1); y <= cy + R + 1; y++)
                for (int x = (int)floor(cx - R - 1); x <= cx + R + 1; x++) {
                    if (x < 0 || y < 0 || x >= width || y >= height)
                        continue;
                    double d = hypot(x + 0.5 - cx, y + 0.5 - cy);
                    double outer = R - d + 0.5, inner = R - 2 - d + 0.5;
                    if (outer <= 0)
                        continue;
                    uint32_t* p = &b->px[y * width + x];
                    double in = inner > 1 ? 1 : inner < 0 ? 0 : inner;
                    blend(p, inverse, 0.75 * ((outer > 1 ? 1 : outer) - in)); // the rim, over what's behind it
                    blend(p, (rgb){0, 0, 0}, in);                               // the disc
                }
            // The loading shape: a 9-lobed cookie (LoadingIndicator's Cookie9Sided), turning
            double s = HOLE_SIZE * unit() * 0.44 * 0.56, r0 = s / 2 * 0.92, rot = t * COOKIE_DEG_PER_S * M_PI / 180;
            for (int y = (int)floor(cy - s / 2); y <= cy + s / 2; y++)
                for (int x = (int)floor(cx - s / 2); x <= cx + s / 2; x++) {
                    double dx = x + 0.5 - cx, dy = y + 0.5 - cy;
                    double rr = r0 * (1 - 0.09 + 0.09 * cos(9 * (atan2(dy, dx) - rot)));
                    double cov = rr - hypot(dx, dy) + 0.5;
                    if (cov > 0)
                        blend(&b->px[y * width + x], primary, cov > 1 ? 1 : cov);
                }
        }
        for (int i = 0; i < RING_DOTS; i++) {
            double a = ang0[i] + phase / pow(ring[i], 1.5), sn = sin(a);
            if ((sn > 0) != (pass == 1))
                continue;
            disc(b->px, cx + cos(a) * ring[i] * R, cy + sn * ring[i] * R * RING_TILT, 1.5, i % 3 == 0 ? tertiary : primary, 0.75);
        }
    }
}

static void frame_done(void* data, struct wl_callback* cb, uint32_t time);
static const struct wl_callback_listener frame_listener = {.done = frame_done};

static void render(void) {
    if (!configured || frame_pending)
        return;
    struct buffer* b = !buffers[0].busy ? &buffers[0] : !buffers[1].busy ? &buffers[1] : NULL;
    if (!b)
        return;
    int x, y, w, h;
    draw_frame(b, now() - t0, &x, &y, &w, &h);
    b->busy = true;
    wl_surface_attach(surface, b->wl, 0, 0);
    wl_surface_damage_buffer(surface, x, y, w, h);
    wl_callback_add_listener(wl_surface_frame(surface), &frame_listener, NULL);
    frame_pending = true;
    wl_surface_commit(surface);
}

static void frame_done(void* data, struct wl_callback* cb, uint32_t time) {
    (void)data, (void)time;
    wl_callback_destroy(cb);
    frame_pending = false;
    render();
}

static void buffer_release(void* data, struct wl_buffer* wl) {
    (void)wl;
    ((struct buffer*)data)->busy = false;
    render();
}
static const struct wl_buffer_listener buffer_listener = {.release = buffer_release};

static bool make_buffers(void) {
    size_t one = (size_t)width * (size_t)height * 4;
    int fd = memfd_create("caelestia-boot-splash", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, (off_t)(one * 2)) < 0)
        return false;
    uint32_t* map = mmap(NULL, one * 2, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED)
        return false;
    struct wl_shm_pool* pool = wl_shm_create_pool(shm, fd, (int32_t)(one * 2));
    for (int i = 0; i < 2; i++) {
        buffers[i].px = map + (size_t)i * (size_t)width * (size_t)height;
        buffers[i].wl = wl_shm_pool_create_buffer(pool, (int32_t)((size_t)i * one), width, height, width * 4, WL_SHM_FORMAT_XRGB8888);
        wl_buffer_add_listener(buffers[i].wl, &buffer_listener, &buffers[i]);
    }
    wl_shm_pool_destroy(pool);
    close(fd);
    base = malloc(one);
    return base != NULL;
}

static void layer_configure(void* data, struct zwlr_layer_surface_v1* ls, uint32_t serial, uint32_t w, uint32_t h) {
    (void)data;
    zwlr_layer_surface_v1_ack_configure(ls, serial);
    if (configured || w == 0 || h == 0)
        return; // one size for its short life
    width = (int)w, height = (int)h;
    if (!make_buffers()) {
        running = 0;
        return;
    }
    draw_base();
    configured = true;
    render();
}

static void layer_closed(void* data, struct zwlr_layer_surface_v1* ls) {
    (void)data, (void)ls;
    running = 0;
}
static const struct zwlr_layer_surface_v1_listener layer_listener = {.configure = layer_configure, .closed = layer_closed};

static void global_add(void* data, struct wl_registry* reg, uint32_t name, const char* iface, uint32_t version) {
    (void)data, (void)version;
    if (!strcmp(iface, wl_compositor_interface.name))
        compositor = wl_registry_bind(reg, name, &wl_compositor_interface, 4);
    else if (!strcmp(iface, wl_shm_interface.name))
        shm = wl_registry_bind(reg, name, &wl_shm_interface, 1);
    else if (!strcmp(iface, zwlr_layer_shell_v1_interface.name))
        layer_shell = wl_registry_bind(reg, name, &zwlr_layer_shell_v1_interface, 1);
}
static void global_remove(void* data, struct wl_registry* reg, uint32_t name) {
    (void)data, (void)reg, (void)name;
}
static const struct wl_registry_listener registry_listener = {.global = global_add, .global_remove = global_remove};

static void on_signal(int sig) {
    (void)sig;
    running = 0;
}

int main(int argc, char** argv) {
    double max_s = argc > 1 ? atof(argv[1]) : 12;
    if (max_s <= 0 || max_s > 60)
        max_s = 12;
    t0 = now();
    for (int i = 0; i < RING_DOTS; i++) { // BlackHole.qml's dots
        ring[i] = 1.5 + qrand(i + 1) * 1.9;
        ang0[i] = qrand(i + 50) * M_PI * 2;
    }
    read_scheme();

    display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "caelestia-boot-splash: no Wayland display\n");
        return 1;
    }
    struct wl_registry* reg = wl_display_get_registry(display);
    wl_registry_add_listener(reg, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!compositor || !shm || !layer_shell) {
        fprintf(stderr, "caelestia-boot-splash: the compositor has no layer shell\n");
        return 1;
    }

    char pidfile[512] = "";
    const char* rt = getenv("XDG_RUNTIME_DIR");
    if (rt && *rt) {
        snprintf(pidfile, sizeof pidfile, "%s/caelestia-boot-splash.pid", rt);
        FILE* f = fopen(pidfile, "w");
        if (f) {
            fprintf(f, "%d\n", (int)getpid());
            fclose(f);
        }
    }
    struct sigaction sa = {.sa_handler = on_signal};
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);

    surface = wl_compositor_create_surface(compositor);
    struct wl_region* empty = wl_compositor_create_region(compositor); // never takes input
    wl_surface_set_input_region(surface, empty);
    wl_region_destroy(empty);
    layer_surface = zwlr_layer_shell_v1_get_layer_surface(layer_shell, surface, NULL, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "caelestia-boot-splash");
    zwlr_layer_surface_v1_set_anchor(layer_surface, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                                                        ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_exclusive_zone(layer_surface, -1);
    zwlr_layer_surface_v1_add_listener(layer_surface, &layer_listener, NULL);
    wl_surface_commit(surface);

    struct pollfd pfd = {.fd = wl_display_get_fd(display), .events = POLLIN};
    while (running && now() - t0 < max_s) {
        while (wl_display_prepare_read(display) != 0)
            if (wl_display_dispatch_pending(display) < 0)
                running = 0;
        if (wl_display_flush(display) < 0 && errno != EAGAIN) {
            wl_display_cancel_read(display);
            break;
        }
        int r = poll(&pfd, 1, 100);
        if (r > 0 && (pfd.revents & POLLIN)) {
            if (wl_display_read_events(display) < 0)
                break;
        } else {
            wl_display_cancel_read(display);
            if (r > 0 && (pfd.revents & (POLLERR | POLLHUP)))
                break;
        }
        if (wl_display_dispatch_pending(display) < 0)
            break;
    }

    if (*pidfile) { // only its own pid file
        FILE* f = fopen(pidfile, "r");
        int pid = 0;
        if (f) {
            if (fscanf(f, "%d", &pid) != 1)
                pid = 0;
            fclose(f);
        }
        if (pid == (int)getpid())
            unlink(pidfile);
    }
    if (layer_surface)
        zwlr_layer_surface_v1_destroy(layer_surface);
    if (surface)
        wl_surface_destroy(surface);
    wl_display_flush(display);
    wl_display_disconnect(display);
    return 0;
}
