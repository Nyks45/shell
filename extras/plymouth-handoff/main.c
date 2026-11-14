// Socket-activated root helper that runs `plymouth deactivate` only at the moment
// Hyprland actually takes over DRM master, avoiding a static frozen splash during
// session setup and dynamic linker/config startup.
//
// Before and right after calling `plymouth deactivate`, paint the animated Nebula
// splash frame onto `/dev/fb0` via pwrite() (which synchronously invokes Linux
// drm_fbdev_ttm_fb_write -> drm_fb_helper_damage_area, unlike mmap + immediate
// munmap/close under fb_deferred_io), then keep animating the center dirty band
// at ~60 fps until Hyprland sends 'S' (after committing Frame 1) or closes the
// handoff socket.

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <math.h>
#include <png.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define SD_LISTEN_FDS_START 3
#define NEBULA_THEME_DIR    "/usr/share/plymouth/themes/nebula"

#define RING_DOTS     90
#define RING_TILT     0.32
#define HOLE_SIZE     160.0
#define CENTER_HEIGHT 0.42
#define SPIN_FRAMES   20
#define SPIN_HZ       50.0
#define SPIN_RATE     ((0.5 + 9 * 0.45) * 1.6)
#define ANIM_MAX_MS   2000

#ifndef HANDOFF_FB_PATH
#define HANDOFF_FB_PATH "/dev/fb0"
#endif

#ifndef HANDOFF_PLYMOUTH_PID_PATH
#define HANDOFF_PLYMOUTH_PID_PATH "/run/plymouth/pid"
#endif

struct rgba_image {
    int width;
    int height;
    uint8_t* pixels; // RGBA8888, non-premultiplied
};

static int load_png_rgba(const char* path, struct rgba_image* out) {
    FILE* fp = fopen(path, "rb");
    if (!fp)
        return -1;

    uint8_t sig[8];
    if (fread(sig, 1, sizeof(sig), fp) != sizeof(sig) || png_sig_cmp(sig, 0, sizeof(sig)) != 0) {
        fclose(fp);
        return -1;
    }

    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) {
        fclose(fp);
        return -1;
    }

    png_infop info = png_create_info_struct(png);
    if (!info) {
        png_destroy_read_struct(&png, NULL, NULL);
        fclose(fp);
        return -1;
    }

    uint8_t* pixels = NULL;
    png_bytep* rows = NULL;
    if (setjmp(png_jmpbuf(png))) {
        free(rows);
        free(pixels);
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return -1;
    }

    png_init_io(png, fp);
    png_set_sig_bytes(png, sizeof(sig));
    png_read_info(png, info);

    png_uint_32 w = png_get_image_width(png, info);
    png_uint_32 h = png_get_image_height(png, info);
    png_byte color_type = png_get_color_type(png, info);
    png_byte bit_depth = png_get_bit_depth(png, info);

    if (bit_depth == 16)
        png_set_strip_16(png);
    if (color_type == PNG_COLOR_TYPE_PALETTE)
        png_set_palette_to_rgb(png);
    if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
        png_set_expand_gray_1_2_4_to_8(png);
    if (png_get_valid(png, info, PNG_INFO_tRNS))
        png_set_tRNS_to_alpha(png);
    if (color_type == PNG_COLOR_TYPE_RGB || color_type == PNG_COLOR_TYPE_GRAY ||
        color_type == PNG_COLOR_TYPE_PALETTE)
        png_set_filler(png, 0xff, PNG_FILLER_AFTER);
    if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
        png_set_gray_to_rgb(png);

    png_read_update_info(png, info);

    size_t rowbytes = png_get_rowbytes(png, info);
    pixels = malloc((size_t)h * rowbytes);
    rows = malloc((size_t)h * sizeof(png_bytep));
    if (!pixels || !rows) {
        free(rows);
        free(pixels);
        png_destroy_read_struct(&png, &info, NULL);
        fclose(fp);
        return -1;
    }

    for (png_uint_32 y = 0; y < h; y++)
        rows[y] = pixels + (size_t)y * rowbytes;

    png_read_image(png, rows);
    free(rows);
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);

    out->width = (int)w;
    out->height = (int)h;
    out->pixels = pixels;
    return 0;
}

static inline uint32_t pack_fb_pixel(
    uint8_t r, uint8_t g, uint8_t b,
    uint32_t r_shift, uint32_t g_shift, uint32_t b_shift, uint32_t a_mask) {
    return a_mask | ((uint32_t)r << r_shift) | ((uint32_t)g << g_shift) | ((uint32_t)b << b_shift);
}

static void blend_rgba_onto_rgb_buf(
    uint8_t* dst_rgb, int dst_w, int dst_h,
    const struct rgba_image* src, int dst_x, int dst_y) {
    int x0 = dst_x < 0 ? 0 : dst_x;
    int y0 = dst_y < 0 ? 0 : dst_y;
    int x1 = dst_x + src->width > dst_w ? dst_w : dst_x + src->width;
    int y1 = dst_y + src->height > dst_h ? dst_h : dst_y + src->height;

    for (int y = y0; y < y1; y++) {
        const uint8_t* srow = src->pixels + ((size_t)(y - dst_y) * (size_t)src->width + (size_t)(x0 - dst_x)) * 4;
        uint8_t* drow = dst_rgb + ((size_t)y * (size_t)dst_w + (size_t)x0) * 3;
        for (int x = x0; x < x1; x++, srow += 4, drow += 3) {
            uint8_t a = srow[3];
            if (a == 0)
                continue;
            if (a == 255) {
                drow[0] = srow[0];
                drow[1] = srow[1];
                drow[2] = srow[2];
            } else {
                uint32_t inv = 255U - a;
                drow[0] = (uint8_t)((srow[0] * a + drow[0] * inv + 127U) / 255U);
                drow[1] = (uint8_t)((srow[1] * a + drow[1] * inv + 127U) / 255U);
                drow[2] = (uint8_t)((srow[2] * a + drow[2] * inv + 127U) / 255U);
            }
        }
    }
}

static double qrand(double seed) {
    double x = sin(seed * 12.9898 + 78.233) * 43758.5453;
    return x - floor(x);
}

static double calc_unit(int w, int h) {
    double u = fmin((double)w / 1920.0, (double)h / 1080.0);
    return fmax(0.65, fmin(1.5, u));
}

static int64_t mono_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec;
}

struct nebula_assets {
    int width;
    int height;
    int cx;
    int cy_hole;
    double radius;
    uint8_t* base_rgb;
    struct rgba_image hole;
    struct rgba_image dot_p;
    struct rgba_image dot_t;
    struct rgba_image spin[SPIN_FRAMES];
    int has_hole;
    int has_dot_p;
    int has_dot_t;
    int has_spin[SPIN_FRAMES];
    double ring[RING_DOTS];
    double ang0[RING_DOTS];
    double speed[RING_DOTS];
    uint8_t tert[RING_DOTS];
    int dirty_x0;
    int dirty_y0;
    int dirty_x1;
    int dirty_y1;
    int dirty_w;
    int dirty_h;
};

static void free_nebula_assets(struct nebula_assets* a) {
    if (!a)
        return;
    free(a->base_rgb);
    free(a->hole.pixels);
    free(a->dot_p.pixels);
    free(a->dot_t.pixels);
    for (int i = 0; i < SPIN_FRAMES; i++)
        free(a->spin[i].pixels);
    memset(a, 0, sizeof(*a));
}

static int init_nebula_assets(int w, int h, const char* theme_dir, struct nebula_assets* a) {
    memset(a, 0, sizeof(*a));
    a->width = w;
    a->height = h;
    a->cx = w / 2;
    a->cy_hole = (int)((double)h * CENTER_HEIGHT);
    a->radius = (HOLE_SIZE * calc_unit(w, h)) / 2.0;

    size_t npix = (size_t)w * (size_t)h;
    a->base_rgb = malloc(npix * 3);
    if (!a->base_rgb)
        return -1;

    // Match NebulaTheme SPACE (#05050F) instead of pure black
    for (size_t i = 0; i < npix; i++) {
        a->base_rgb[i * 3 + 0] = 0x05;
        a->base_rgb[i * 3 + 1] = 0x05;
        a->base_rgb[i * 3 + 2] = 0x0F;
    }

    char path[256];
    struct rgba_image stars = {0};
    snprintf(path, sizeof(path), "%s/stars.png", theme_dir);
    if (load_png_rgba(path, &stars) == 0) {
        blend_rgba_onto_rgb_buf(a->base_rgb, w, h, &stars, a->cx - stars.width / 2, h / 2 - stars.height / 2);
        free(stars.pixels);
    }

    struct rgba_image halo = {0};
    snprintf(path, sizeof(path), "%s/halo.png", theme_dir);
    if (load_png_rgba(path, &halo) == 0) {
        blend_rgba_onto_rgb_buf(a->base_rgb, w, h, &halo, a->cx - halo.width / 2, a->cy_hole - halo.height / 2);
        free(halo.pixels);
    }

    snprintf(path, sizeof(path), "%s/hole-7.png", theme_dir);
    a->has_hole = (load_png_rgba(path, &a->hole) == 0);
    snprintf(path, sizeof(path), "%s/dot-p.png", theme_dir);
    a->has_dot_p = (load_png_rgba(path, &a->dot_p) == 0);
    snprintf(path, sizeof(path), "%s/dot-t.png", theme_dir);
    a->has_dot_t = (load_png_rgba(path, &a->dot_t) == 0);

    int max_spin_hw = 0;
    int max_spin_hh = 0;
    for (int i = 0; i < SPIN_FRAMES; i++) {
        snprintf(path, sizeof(path), "%s/spin-%02d.png", theme_dir, i);
        if (load_png_rgba(path, &a->spin[i]) == 0) {
            a->has_spin[i] = 1;
            if (a->spin[i].width / 2 + 2 > max_spin_hw)
                max_spin_hw = a->spin[i].width / 2 + 2;
            if (a->spin[i].height / 2 + 2 > max_spin_hh)
                max_spin_hh = a->spin[i].height / 2 + 2;
        }
    }

    for (int i = 0; i < RING_DOTS; i++) {
        a->ring[i] = 1.5 + qrand(i + 1) * 1.9;
        a->ang0[i] = qrand(i + 50) * 2.0 * M_PI;
        a->speed[i] = pow(a->ring[i], -1.5);
        a->tert[i] = (uint8_t)(i % 3 == 0);
    }

    int dot_hw = (a->has_dot_p ? a->dot_p.width / 2 : 3) + 4;
    int dot_hh = (a->has_dot_p ? a->dot_p.height / 2 : 3) + 4;
    int half_w = (int)ceil(3.4 * a->radius) + dot_hw;
    int half_h = (int)ceil(3.4 * a->radius * RING_TILT) + dot_hh;
    if (a->has_hole) {
        if (a->hole.width / 2 + 2 > half_w)
            half_w = a->hole.width / 2 + 2;
        if (a->hole.height / 2 + 2 > half_h)
            half_h = a->hole.height / 2 + 2;
    }
    if (max_spin_hw > half_w)
        half_w = max_spin_hw;
    if (max_spin_hh > half_h)
        half_h = max_spin_hh;

    a->dirty_x0 = a->cx - half_w;
    if (a->dirty_x0 < 0)
        a->dirty_x0 = 0;
    a->dirty_x1 = a->cx + half_w;
    if (a->dirty_x1 > w)
        a->dirty_x1 = w;
    a->dirty_y0 = a->cy_hole - half_h;
    if (a->dirty_y0 < 0)
        a->dirty_y0 = 0;
    a->dirty_y1 = a->cy_hole + half_h;
    if (a->dirty_y1 > h)
        a->dirty_y1 = h;
    a->dirty_w = a->dirty_x1 - a->dirty_x0;
    a->dirty_h = a->dirty_y1 - a->dirty_y0;
    return 0;
}

static void draw_orbit_dots(const struct nebula_assets* a, double phase, int front_half, uint8_t* dirty_rgb) {
    for (int i = 0; i < RING_DOTS; i++) {
        const struct rgba_image* dot = a->tert[i] ? (a->has_dot_t ? &a->dot_t : NULL) : (a->has_dot_p ? &a->dot_p : NULL);
        if (!dot)
            continue;
        double ang = a->ang0[i] + phase * a->speed[i];
        double sn = sin(ang);
        if (front_half ? (sn <= 0.0) : (sn > 0.0))
            continue;
        double r = a->ring[i] * a->radius;
        int dx = (int)lround((double)a->cx + cos(ang) * r) - dot->width / 2 - a->dirty_x0;
        int dy = (int)lround((double)a->cy_hole + sn * r * RING_TILT) - dot->height / 2 - a->dirty_y0;
        blend_rgba_onto_rgb_buf(dirty_rgb, a->dirty_w, a->dirty_h, dot, dx, dy);
    }
}

static void render_nebula_dirty_rgb(const struct nebula_assets* a, double t, uint8_t* dirty_rgb) {
    for (int row = 0; row < a->dirty_h; row++) {
        const uint8_t* src = a->base_rgb + ((size_t)(a->dirty_y0 + row) * (size_t)a->width + (size_t)a->dirty_x0) * 3;
        memcpy(dirty_rgb + (size_t)row * (size_t)a->dirty_w * 3, src, (size_t)a->dirty_w * 3);
    }

    double phase = t * SPIN_RATE;

    // Layer order: back dots -> black hole disc -> rotating cookie -> front dots
    draw_orbit_dots(a, phase, 0, dirty_rgb);

    if (a->has_hole) {
        blend_rgba_onto_rgb_buf(
            dirty_rgb, a->dirty_w, a->dirty_h, &a->hole,
            a->cx - a->hole.width / 2 - a->dirty_x0,
            a->cy_hole - a->hole.height / 2 - a->dirty_y0);
    }

    int sf = (int)floor(t * SPIN_HZ);
    if (sf < 0)
        sf = 0;
    sf %= SPIN_FRAMES;
    if (a->has_spin[sf]) {
        const struct rgba_image* sp = &a->spin[sf];
        blend_rgba_onto_rgb_buf(
            dirty_rgb, a->dirty_w, a->dirty_h, sp,
            a->cx - sp->width / 2 - a->dirty_x0,
            a->cy_hole - sp->height / 2 - a->dirty_y0);
    }

    draw_orbit_dots(a, phase, 1, dirty_rgb);
}

struct fb_buffer {
    uint8_t* data;
    size_t size;
    off_t offset;
    uint32_t line_length;
    uint32_t r_shift;
    uint32_t g_shift;
    uint32_t b_shift;
    uint32_t a_mask;
    uint8_t* dirty_rgb;
    uint8_t* dirty_fb;
    size_t dirty_fb_size;
    off_t dirty_fb_offset;
};

static int prepare_nebula_fb_buffer(const struct fb_fix_screeninfo* finfo,
                                    const struct fb_var_screeninfo* vinfo,
                                    const struct nebula_assets* a,
                                    struct fb_buffer* out) {
    if (vinfo->bits_per_pixel != 32 || vinfo->xres == 0 || vinfo->yres == 0 ||
        finfo->line_length < vinfo->xres * 4 || a->dirty_w <= 0 || a->dirty_h <= 0)
        return -1;

    int w = (int)vinfo->xres;
    int h = (int)vinfo->yres;
    size_t buf_size = (size_t)h * (size_t)finfo->line_length;
    uint8_t* packed = calloc(1, buf_size);
    uint8_t* dirty_rgb = malloc((size_t)a->dirty_w * (size_t)a->dirty_h * 3);
    size_t dirty_fb_size = (size_t)a->dirty_h * (size_t)finfo->line_length;
    uint8_t* dirty_fb = malloc(dirty_fb_size);
    if (!packed || !dirty_rgb || !dirty_fb) {
        free(packed);
        free(dirty_rgb);
        free(dirty_fb);
        return -1;
    }

    out->r_shift = vinfo->red.offset;
    out->g_shift = vinfo->green.offset;
    out->b_shift = vinfo->blue.offset;
    out->a_mask = vinfo->transp.length ? (0xFFU << vinfo->transp.offset) : 0xFF000000U;
    out->line_length = finfo->line_length;

    for (int y = 0; y < h; y++) {
        const uint8_t* srow = a->base_rgb + (size_t)y * (size_t)w * 3;
        uint32_t* drow = (uint32_t*)(packed + (size_t)y * finfo->line_length);
        for (int x = 0; x < w; x++, srow += 3)
            drow[x] = pack_fb_pixel(srow[0], srow[1], srow[2], out->r_shift, out->g_shift, out->b_shift, out->a_mask);
    }

    out->data = packed;
    out->size = buf_size;
    out->offset = (off_t)vinfo->yoffset * (off_t)finfo->line_length;
    out->dirty_rgb = dirty_rgb;
    out->dirty_fb = dirty_fb;
    out->dirty_fb_size = dirty_fb_size;
    out->dirty_fb_offset = out->offset + (off_t)a->dirty_y0 * (off_t)finfo->line_length;
    memcpy(out->dirty_fb, packed + (size_t)a->dirty_y0 * finfo->line_length, dirty_fb_size);
    return 0;
}

static void update_fb_dirty_frame(const struct nebula_assets* a, double t, struct fb_buffer* buf) {
    render_nebula_dirty_rgb(a, t, buf->dirty_rgb);
    for (int row = 0; row < a->dirty_h; row++) {
        const uint8_t* srow = buf->dirty_rgb + (size_t)row * (size_t)a->dirty_w * 3;
        uint32_t* drow_dirty = (uint32_t*)(buf->dirty_fb + (size_t)row * buf->line_length) + a->dirty_x0;
        uint32_t* drow_full = (uint32_t*)(buf->data + (size_t)(a->dirty_y0 + row) * buf->line_length) + a->dirty_x0;
        for (int x = 0; x < a->dirty_w; x++, srow += 3) {
            uint32_t px = pack_fb_pixel(srow[0], srow[1], srow[2], buf->r_shift, buf->g_shift, buf->b_shift, buf->a_mask);
            drow_dirty[x] = px;
            drow_full[x] = px;
        }
    }
}

static void pwrite_all(int fbfd, const uint8_t* data, size_t size, off_t offset) {
    if (fbfd < 0 || !data)
        return;

    size_t written = 0;
    while (written < size) {
        ssize_t n = pwrite(fbfd, data + written, size - written, offset + (off_t)written);
        if (n < 0) {
            if (errno == EINTR)
                continue;
            break;
        }
        if (n == 0)
            break;
        written += (size_t)n;
    }
}

static void free_fb_buffer(struct fb_buffer* buf) {
    if (!buf)
        return;
    free(buf->data);
    free(buf->dirty_rgb);
    free(buf->dirty_fb);
    memset(buf, 0, sizeof(*buf));
}

static int drain_stop_signal(int cfd) {
    char tmp[64];
    ssize_t n = read(cfd, tmp, sizeof(tmp));
    if (n == 0)
        return 1;
    if (n < 0)
        return (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) ? 0 : 1;
    for (ssize_t i = 0; i < n; i++) {
        if (tmp[i] == 'S')
            return 1;
    }
    return 0;
}

static int run_handoff_session(int cfd, const char* fb_path, const char* plymouth_pid_path, const char* theme_dir) {
    struct pollfd cpfd = {.fd = cfd, .events = POLLIN};
    if (poll(&cpfd, 1, 1000) > 0) {
        char req = 0;
        (void)read(cfd, &req, 1);
    }

    int fbfd = -1;
    int has_fb = 0;
    struct nebula_assets assets = {0};
    struct fb_buffer fbuf = {0};
    int64_t t0_ns = mono_ns();

    if (access(plymouth_pid_path, F_OK) == 0) {
        fbfd = open(fb_path, O_RDWR | O_CLOEXEC);
        if (fbfd >= 0) {
            struct fb_fix_screeninfo finfo;
            struct fb_var_screeninfo vinfo;
            if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo) == 0 &&
                ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo) == 0 &&
                init_nebula_assets((int)vinfo.xres, (int)vinfo.yres, theme_dir, &assets) == 0 &&
                prepare_nebula_fb_buffer(&finfo, &vinfo, &assets, &fbuf) == 0) {
                has_fb = 1;
                t0_ns = mono_ns();
                update_fb_dirty_frame(&assets, 0.0, &fbuf);
                pwrite_all(fbfd, fbuf.data, fbuf.size, fbuf.offset);
            } else {
                free_nebula_assets(&assets);
                close(fbfd);
                fbfd = -1;
            }
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

        if (has_fb) {
            double t = (double)(mono_ns() - t0_ns) / 1e9;
            update_fb_dirty_frame(&assets, t, &fbuf);
            pwrite_all(fbfd, fbuf.data, fbuf.size, fbuf.offset);
        }
    }

    char ack = 'K';
    (void)write(cfd, &ack, 1);

    if (has_fb) {
        int fl = fcntl(cfd, F_GETFL, 0);
        if (fl >= 0)
            (void)fcntl(cfd, F_SETFL, fl | O_NONBLOCK);

        const int64_t frame_ns = 16666667LL; // ~60 fps
        int64_t deadline_ns = mono_ns() + (int64_t)ANIM_MAX_MS * 1000000LL;
        int64_t next_tick_ns = mono_ns() + frame_ns;

        for (;;) {
            int64_t now = mono_ns();
            if (now >= deadline_ns)
                break;

            int64_t rem_ms = (next_tick_ns - now + 999999LL) / 1000000LL;
            if (rem_ms < 0)
                rem_ms = 0;
            if (rem_ms > 20)
                rem_ms = 20;

            struct pollfd wpfd = {.fd = cfd, .events = POLLIN};
            int pr = poll(&wpfd, 1, (int)rem_ms);
            if (pr > 0) {
                if (wpfd.revents & (POLLHUP | POLLERR | POLLNVAL))
                    break;
                if ((wpfd.revents & POLLIN) && drain_stop_signal(cfd))
                    break;
            }

            now = mono_ns();
            if (now >= next_tick_ns) {
                double t = (double)(now - t0_ns) / 1e9;
                update_fb_dirty_frame(&assets, t, &fbuf);
                pwrite_all(fbfd, fbuf.dirty_fb, fbuf.dirty_fb_size, fbuf.dirty_fb_offset);
                while (next_tick_ns <= now)
                    next_tick_ns += frame_ns;
            }
        }

        free_fb_buffer(&fbuf);
        free_nebula_assets(&assets);
    }

    if (fbfd >= 0)
        close(fbfd);
    close(cfd);
    return 0;
}

#ifndef UNIT_TEST
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

    return run_handoff_session(cfd, HANDOFF_FB_PATH, HANDOFF_PLYMOUTH_PID_PATH, NEBULA_THEME_DIR);
}
#endif
