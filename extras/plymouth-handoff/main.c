// Socket-activated root helper that runs `plymouth deactivate` only at the moment
// Hyprland actually takes over DRM master, avoiding a static frozen splash during
// session setup and dynamic linker/config startup.
//
// Before calling `plymouth deactivate`, paint the initial static Nebula splash
// frame onto `/dev/fb0` (the kernel drmfb console backing store, otherwise left
// all-black by `quiet`) so that when `nvidia-drm` drops Plymouth's DRM master
// and restores fbdev while Hyprland finishes EGL/GLES init (~576ms), the screen
// keeps showing Nebula instead of flashing black.

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <png.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

#define SD_LISTEN_FDS_START 3
#define NEBULA_THEME_DIR    "/usr/share/plymouth/themes/nebula"

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

static void paint_nebula_fb0(void) {
    int fbfd = open("/dev/fb0", O_RDWR | O_CLOEXEC);
    if (fbfd < 0)
        return;

    struct fb_fix_screeninfo finfo;
    struct fb_var_screeninfo vinfo;
    if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo) < 0 ||
        ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo) < 0) {
        close(fbfd);
        return;
    }

    if (vinfo.bits_per_pixel != 32 || vinfo.xres == 0 || vinfo.yres == 0 ||
        finfo.line_length < vinfo.xres * 4) {
        close(fbfd);
        return;
    }

    int w = (int)vinfo.xres;
    int h = (int)vinfo.yres;
    size_t row_end = (size_t)(vinfo.yoffset + vinfo.yres) * (size_t)finfo.line_length;
    size_t map_len = finfo.smem_len > row_end ? finfo.smem_len : row_end;

    uint8_t* fb = mmap(NULL, map_len, PROT_READ | PROT_WRITE, MAP_SHARED, fbfd, 0);
    if (fb == MAP_FAILED) {
        close(fbfd);
        return;
    }

    uint8_t* canvas = calloc((size_t)w * (size_t)h, 3);
    if (!canvas) {
        munmap(fb, map_len);
        close(fbfd);
        return;
    }

    // Match nebula.script layout: fullscreen stars + center-anchored elements at (W/2, H*0.42)
    static const struct {
        const char* name;
        int at_hole_center;
    } layers[] = {
        {"stars.png", 0},
        {"halo.png", 1},
        {"hole-7.png", 1},
        {"spin-00.png", 1},
    };

    int cx = w / 2;
    int cy_hole = (int)((double)h * 0.42);
    int cy_mid = h / 2;

    for (size_t i = 0; i < sizeof(layers) / sizeof(layers[0]); i++) {
        char path[256];
        snprintf(path, sizeof(path), "%s/%s", NEBULA_THEME_DIR, layers[i].name);
        struct rgba_image img = {0};
        if (load_png_rgba(path, &img) == 0) {
            int dx = cx - img.width / 2;
            int dy = (layers[i].at_hole_center ? cy_hole : cy_mid) - img.height / 2;
            blend_rgba_onto_rgb_buf(canvas, w, h, &img, dx, dy);
            free(img.pixels);
        }
    }

    uint32_t r_shift = vinfo.red.offset;
    uint32_t g_shift = vinfo.green.offset;
    uint32_t b_shift = vinfo.blue.offset;
    uint32_t a_mask = vinfo.transp.length ? (0xFFU << vinfo.transp.offset) : 0xFF000000U;

    for (int y = 0; y < h; y++) {
        const uint8_t* srow = canvas + (size_t)y * (size_t)w * 3;
        uint32_t* drow = (uint32_t*)(fb + (size_t)(vinfo.yoffset + (uint32_t)y) * finfo.line_length) +
                         vinfo.xoffset;
        for (int x = 0; x < w; x++, srow += 3)
            drow[x] = pack_fb_pixel(srow[0], srow[1], srow[2], r_shift, g_shift, b_shift, a_mask);
    }

    free(canvas);
    msync(fb, map_len, MS_SYNC);
    munmap(fb, map_len);
    close(fbfd);
}

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

    if (access("/run/plymouth/pid", F_OK) == 0) {
        paint_nebula_fb0();

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
    }

    char ack = 'K';
    (void)write(cfd, &ack, 1);
    close(cfd);
    return 0;
}
