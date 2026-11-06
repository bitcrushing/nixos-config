/* The expensive painting happens at Nix build time. Sky/details use partial
 * updates; gentle film grain refreshes the whole image at a lower cadence.
 * No toolkit, video decoder, GPU shader loop, or polling IPC.
 * The compositor still has to composite damage: animation is not free. */
#define _GNU_SOURCE
#include <errno.h>
#include <immintrin.h>
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
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-layer-shell-unstable-v1.h"

#define MAX_OUTPUTS 16
#define MAX_EFFECTS 8192
#define MAX_CLOUDS 12
#define DAMAGE_WIDTH 128
#define DAMAGE_HEIGHT 32
#define TAU 6.283185307179586
#define SKY_KEYFRAME_SECONDS 0.5
#define GRAIN_SIDE 512
#define GRAIN_STRIDE (GRAIN_SIDE + 16)

struct rect { int x, y, w, h; };
struct span { int x, y, width; };
struct effect {
    char kind;
    double x, y, length, rate, phase, strength, depth, r, g, b;
};
struct buffer {
    struct wl_buffer *wl;
    uint32_t *pixels;
    bool busy;
    int count;
    struct rect rects[MAX_EFFECTS];
    uint64_t cloud_serial;
    int64_t film_epoch;
    bool initialized;
};
struct output {
    uint32_t id;
    struct wl_output *wl;
    struct wl_surface *surface;
    struct zwlr_layer_surface_v1 *layer;
    struct wl_callback *frame;
    struct buffer buffers[2];
    int index, count;
    struct rect previous[MAX_EFFECTS];
    bool configured, painted;
    double next;
    uint64_t cloud_serial;
    int64_t film_epoch;
};
struct cloud {
    char kind;
    int y, height, offset;
    unsigned fraction;
    int breath;
    double speed;
    unsigned r, g, b;
    const uint8_t *data;
    uint8_t *damage_tiles;
    struct span *spans;
    int span_count;
    uint64_t serial;
};
static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *shell;
static struct output outputs[MAX_OUTPUTS];
static struct effect effects[MAX_EFFECTS];
static const uint32_t *base;
static int width, height, output_width, effect_count, output_count;
static char **output_names;
static bool globals_ready;
static volatile sig_atomic_t running = 1, paused;
static double interval = 1.0 / 24;
static struct cloud clouds[MAX_CLOUDS];
static int cloud_y, cloud_height, cloud_count;
static size_t layer_data_size;
static const uint8_t *layer_data, *sky_mask;
static struct span *sky_spans;
static int sky_span_count;
static uint32_t *cloud_background;
static uint32_t *previous_sky;
static int64_t sky_keyframe = -1;
static unsigned sky_blend;
static bool moving_sky;
static uint64_t cloud_serial;
static const int8_t *film_source, *film_noise;
static int8_t *scaled_film_noise;
static bool film_enabled;
static double grain_fps = 8, grain_strength = 0.8;
static int64_t film_epoch = -1;
static uint32_t film_phase;
static int film_exposure;
static bool use_avx2;

static void fail(const char *message) {
    fprintf(stderr, "twilight-wallpaper: %s\n", message);
    exit(EXIT_FAILURE);
}

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

static void load_scene(const char *directory) {
    /* Use wider integer kernels where available, retaining the x86_64/SSE2
     * baseline and exactly the same rounding on older machines. */
    use_avx2 = __builtin_cpu_supports("avx2");
    char *path;
    if (asprintf(&path, "%s/scene.txt", directory) < 0) fail("out of memory");
    FILE *f = fopen(path, "r");
    free(path);
    if (!f) fail("cannot open scene.txt");
    if (fscanf(f, "TWILIGHT1 %d %d", &width, &height) != 2 ||
        width < 1 || width > 32768 || height < 1 || height > 8192 ||
        width % output_count) fail("invalid scene dimensions");
    output_width = width / output_count;
    for (;;) {
        struct effect e;
        int n = fscanf(f, " %c %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf",
            &e.kind, &e.x, &e.y, &e.length, &e.rate, &e.phase,
            &e.strength, &e.depth, &e.r, &e.g, &e.b);
        if (n == EOF) break;
        if (n != 11 || !strchr("SRFM", e.kind) || effect_count == MAX_EFFECTS)
            fail("invalid scene detail");
        effects[effect_count++] = e;
    }
    fclose(f);
    if (asprintf(&path, "%s/base.argb", directory) < 0) fail("out of memory");
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    free(path);
    struct stat st;
    size_t size = (size_t)width * height * 4;
    if (fd < 0 || fstat(fd, &st) || st.st_size != (off_t)size)
        fail("missing or incorrectly sized base.argb");
    base = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (base == MAP_FAILED) fail("cannot map base.argb");
}

static const void *map_asset(const char *directory, const char *name, size_t size) {
    char *path;
    if (asprintf(&path, "%s/%s", directory, name) < 0) fail("out of memory");
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    free(path);
    struct stat st;
    if (fd < 0 || fstat(fd, &st) || st.st_size != (off_t)size)
        fail("missing or incorrectly sized cloud asset");
    void *data = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (data == MAP_FAILED) fail("cannot map cloud asset");
    return data;
}

static int detail_offset(int value, unsigned mask) {
    int n = value * (int)mask;
    return n < 0 ? -((-n + 127) / 255) : (n + 127) / 255;
}

static int sampled_detail_offset(int a, int b, unsigned fraction, unsigned mask) {
    if (!fraction) return detail_offset(a, mask);
    int n = (a * (int)(256 - fraction) + b * (int)fraction) * (int)mask;
    return n < 0 ? -((-n + 32640) / 65280) : (n + 32640) / 65280;
}

static unsigned clamp_channel(int value) {
    return value < 0 ? 0 : value > 255 ? 255 : (unsigned)value;
}

static void update_film(double t) {
    if (!film_enabled) return;
    int64_t epoch = (int64_t)floor(t * grain_fps);
    if (epoch == film_epoch) return;
    film_epoch = epoch;
    uint32_t hash = (uint32_t)epoch ^ (uint32_t)((uint64_t)epoch >> 32);
    hash ^= hash >> 16;
    hash *= 0x7feb352du;
    hash ^= hash >> 15;
    hash *= 0x846ca68bu;
    film_phase = hash ^ (hash >> 16);
    double time = epoch / grain_fps;
    film_exposure = (int)lround(grain_strength *
        (4 * sin(TAU * time / 18) + 2 * sin(TAU * time / 31)));
}

static void load_film(const char *directory) {
    const char *strength = getenv("TWILIGHT_GRAIN_STRENGTH");
    const char *fps = getenv("TWILIGHT_GRAIN_FPS");
    char *end;
    if (strength) {
        grain_strength = strtod(strength, &end);
        if (!*strength || *end || !isfinite(grain_strength) || grain_strength < 0 || grain_strength > 2)
            fail("TWILIGHT_GRAIN_STRENGTH must be 0..2");
    }
    if (fps) {
        grain_fps = strtod(fps, &end);
        if (!*fps || *end || !isfinite(grain_fps) || grain_fps < 1 || grain_fps > 24)
            fail("TWILIGHT_GRAIN_FPS must be 1..24");
    }
    if (!grain_strength) return;
    size_t size = GRAIN_SIDE * GRAIN_STRIDE;
    film_source = map_asset(directory, "film-grain.i8", size);
    film_noise = film_source;
    if (grain_strength != 1) {
        scaled_film_noise = malloc(size);
        if (!scaled_film_noise) fail("cannot allocate film grain tile");
        for (size_t i = 0; i < size; i++) {
            int value = (int)lround(film_source[i] * grain_strength);
            scaled_film_noise[i] = value < -112 ? -112 : value > 112 ? 112 : value;
        }
        film_noise = scaled_film_noise;
    }
    film_enabled = true;
    update_film(0);
}

static uint32_t film_pixel(uint32_t value, int noise) {
    unsigned r = (value >> 16) & 255, g = (value >> 8) & 255, b = value & 255;
    int luma = (int)((r + 2 * g + b) >> 2);
    int n = (noise + film_exposure) * luma + 1024;
    int delta = n < 0 ? -((-n + 2047) / 2048) : n / 2048;
    return 0xff000000u | (clamp_channel((int)r + delta) << 16) |
           (clamp_channel((int)g + delta) << 8) | clamp_channel((int)b + delta);
}

static void apply_film_row_sse2(uint32_t *pixels, int count, int world_x, int y) {
    if (!film_enabled) return;
    const int8_t *row = film_noise + ((y + (film_phase >> 9)) & (GRAIN_SIDE - 1)) * GRAIN_STRIDE;
    __m128i zero = _mm_setzero_si128(), byte = _mm_set1_epi32(255);
    __m128i exposure = _mm_set1_epi16((short)film_exposure), round = _mm_set1_epi16(1024);
    __m128i opaque = _mm_set1_epi32((int)0xff000000u);
    int x = 0;
    while (x < count) {
        int world = world_x + x;
        int end = x + GRAIN_SIDE - (world & (GRAIN_SIDE - 1));
        if (end > count) end = count;
        unsigned shift = film_phase + (unsigned)(world / GRAIN_SIDE) * 211u + (unsigned)(y / GRAIN_SIDE) * 97u;
        for (; x < end && ((world_x + x) & 3); x++)
            pixels[x] = film_pixel(pixels[x], row[(world_x + x + shift) & (GRAIN_SIDE - 1)]);
        for (; x + 4 <= end; x += 4) {
            __m128i p = _mm_loadu_si128((const __m128i *)(pixels + x));
            __m128i lum = _mm_add_epi32(_mm_and_si128(p, byte), _mm_and_si128(_mm_srli_epi32(p, 16), byte));
            lum = _mm_add_epi32(lum, _mm_slli_epi32(_mm_and_si128(_mm_srli_epi32(p, 8), byte), 1));
            lum = _mm_srli_epi32(lum, 2);
            __m128i level = _mm_packs_epi32(lum, zero);
            const int8_t *noise = row + ((world_x + x + shift) & (GRAIN_SIDE - 1));
            __m128i n = _mm_loadl_epi64((const __m128i *)noise);
            n = _mm_add_epi16(_mm_unpacklo_epi8(n, _mm_cmpgt_epi8(zero, n)), exposure);
            __m128i delta = _mm_srai_epi16(_mm_add_epi16(_mm_mullo_epi16(level, n), round), 11);
            __m128i paired = _mm_unpacklo_epi16(delta, delta);
            __m128i lo = _mm_add_epi16(_mm_unpacklo_epi8(p, zero), _mm_unpacklo_epi32(paired, paired));
            __m128i hi = _mm_add_epi16(_mm_unpackhi_epi8(p, zero), _mm_unpackhi_epi32(paired, paired));
            _mm_storeu_si128((__m128i *)(pixels + x), _mm_or_si128(_mm_packus_epi16(lo, hi), opaque));
        }
        for (; x < end; x++)
            pixels[x] = film_pixel(pixels[x], row[(world_x + x + shift) & (GRAIN_SIDE - 1)]);
    }
}

__attribute__((target("avx2")))
static void apply_film_row_avx2(uint32_t *pixels, int count, int world_x, int y) {
    const int8_t *row = film_noise + ((y + (film_phase >> 9)) & (GRAIN_SIDE - 1)) * GRAIN_STRIDE;
    __m256i zero = _mm256_setzero_si256(), byte = _mm256_set1_epi32(255);
    __m256i exposure = _mm256_set1_epi32(film_exposure), round = _mm256_set1_epi32(1024);
    __m256i opaque = _mm256_set1_epi32((int)0xff000000u);
    int x = 0;
    while (x < count) {
        int world = world_x + x;
        int end = x + GRAIN_SIDE - (world & (GRAIN_SIDE - 1));
        if (end > count) end = count;
        unsigned shift = film_phase + (unsigned)(world / GRAIN_SIDE) * 211u + (unsigned)(y / GRAIN_SIDE) * 97u;
        for (; x + 8 <= end; x += 8) {
            __m256i p = _mm256_loadu_si256((const __m256i *)(pixels + x));
            __m256i lum = _mm256_add_epi32(_mm256_and_si256(p, byte), _mm256_and_si256(_mm256_srli_epi32(p, 16), byte));
            lum = _mm256_add_epi32(lum, _mm256_slli_epi32(_mm256_and_si256(_mm256_srli_epi32(p, 8), byte), 1));
            lum = _mm256_srli_epi32(lum, 2);
            const int8_t *noise = row + ((world_x + x + shift) & (GRAIN_SIDE - 1));
            __m256i n = _mm256_add_epi32(_mm256_cvtepi8_epi32(_mm_loadl_epi64((const __m128i *)noise)), exposure);
            __m256i delta = _mm256_srai_epi32(_mm256_add_epi32(_mm256_mullo_epi32(lum, n), round), 11);
            delta = _mm256_packs_epi32(delta, zero);
            __m256i paired = _mm256_unpacklo_epi16(delta, delta);
            __m256i lo = _mm256_add_epi16(_mm256_unpacklo_epi8(p, zero), _mm256_unpacklo_epi32(paired, paired));
            __m256i hi = _mm256_add_epi16(_mm256_unpackhi_epi8(p, zero), _mm256_unpackhi_epi32(paired, paired));
            _mm256_storeu_si256((__m256i *)(pixels + x), _mm256_or_si256(_mm256_packus_epi16(lo, hi), opaque));
        }
        for (; x < end; x++)
            pixels[x] = film_pixel(pixels[x], row[(world_x + x + shift) & (GRAIN_SIDE - 1)]);
    }
}

static void apply_film_row(uint32_t *pixels, int count, int world_x, int y) {
    if (!film_enabled) return;
    if (use_avx2) apply_film_row_avx2(pixels, count, world_x, y);
    else apply_film_row_sse2(pixels, count, world_x, y);
}

static unsigned layer_stride(char kind) {
    return kind == 'P' ? 4 : kind == 'G' ? 3 : 1;
}

static unsigned glow_opacity(unsigned narrow, unsigned wide, unsigned modulation, unsigned breath) {
    unsigned phase = (modulation * 3 + breath + 2) / 4;
    unsigned broad_weight = 26 + (phase * 102 + 127) / 255;
    unsigned amount = (narrow * (255 - broad_weight) + wide * broad_weight + 127) / 255;
    unsigned gain = 220 + (phase * 72 + 127) / 255;
    amount = (amount * gain + 128) >> 8;
    return amount > 255 ? 255 : amount;
}

static void compose_alpha_run_scalar(uint32_t *dest, const uint8_t *a, const uint8_t *neighbor,
                                     int count, const struct cloud *c) {
    for (int x = 0; x < count; x++) {
        unsigned alpha = a[x];
        if (c->fraction)
            alpha = (alpha * (256 - c->fraction) + neighbor[x] * c->fraction + 128) >> 8;
        if (!alpha) continue;
        uint32_t v = dest[x];
        unsigned r = (((v >> 16) & 255) * (255 - alpha) + c->r * alpha + 127) / 255;
        unsigned g = (((v >> 8) & 255) * (255 - alpha) + c->g * alpha + 127) / 255;
        unsigned b = ((v & 255) * (255 - alpha) + c->b * alpha + 127) / 255;
        dest[x] = 0xff000000u | (r << 16) | (g << 8) | b;
    }
}

__attribute__((target("avx2")))
static __m256i divide255_16(__m256i value) {
    /* Exact floor(value / 255) for the blend's 0..65152 numerator. The
     * correction still fits in 16 bits; using /256 would change the paint. */
    return _mm256_srli_epi16(_mm256_add_epi16(_mm256_add_epi16(value,
        _mm256_set1_epi16(1)), _mm256_srli_epi16(value, 8)), 8);
}

__attribute__((target("avx2")))
static void compose_alpha_run_avx2(uint32_t *dest, const uint8_t *a, const uint8_t *neighbor,
                                   int count, const struct cloud *c) {
    __m256i zero = _mm256_setzero_si256(), full = _mm256_set1_epi16(255);
    __m256i round = _mm256_set1_epi16(127), opaque = _mm256_set1_epi32((int)0xff000000u);
    __m256i tint = _mm256_set1_epi32((int)(0xff000000u | (c->r << 16) | (c->g << 8) | c->b));
    tint = _mm256_unpacklo_epi8(tint, zero);
    __m128i wa = _mm_set1_epi16((short)(256 - c->fraction));
    __m128i wb = _mm_set1_epi16((short)c->fraction), sample_round = _mm_set1_epi16(128);
    int x = 0;
    for (; x + 8 <= count; x += 8) {
        __m128i alpha = _mm_cvtepu8_epi16(_mm_loadl_epi64((const __m128i *)(a + x)));
        if (c->fraction) {
            __m128i next = _mm_cvtepu8_epi16(_mm_loadl_epi64((const __m128i *)(neighbor + x)));
            alpha = _mm_srli_epi16(_mm_add_epi16(_mm_add_epi16(_mm_mullo_epi16(alpha, wa),
                _mm_mullo_epi16(next, wb)), sample_round), 8);
        }
        if (_mm_testz_si128(alpha, alpha)) continue;
        __m256i levels = _mm256_packs_epi32(_mm256_cvtepu16_epi32(alpha), zero);
        __m256i paired = _mm256_unpacklo_epi16(levels, levels);
        __m256i al = _mm256_unpacklo_epi32(paired, paired), ah = _mm256_unpackhi_epi32(paired, paired);
        __m256i pixels = _mm256_loadu_si256((const __m256i *)(dest + x));
        __m256i lo = _mm256_add_epi16(_mm256_mullo_epi16(_mm256_unpacklo_epi8(pixels, zero),
            _mm256_sub_epi16(full, al)), _mm256_mullo_epi16(tint, al));
        __m256i hi = _mm256_add_epi16(_mm256_mullo_epi16(_mm256_unpackhi_epi8(pixels, zero),
            _mm256_sub_epi16(full, ah)), _mm256_mullo_epi16(tint, ah));
        lo = divide255_16(_mm256_add_epi16(lo, round));
        hi = divide255_16(_mm256_add_epi16(hi, round));
        _mm256_storeu_si256((__m256i *)(dest + x), _mm256_or_si256(_mm256_packus_epi16(lo, hi), opaque));
    }
    compose_alpha_run_scalar(dest + x, a + x, neighbor + x, count - x, c);
}

static void compose_alpha_span(const struct cloud *c, struct span span) {
    const uint8_t *row = c->data + (span.y - c->y) * width;
    uint32_t *dest = cloud_background + (span.y - cloud_y) * width + span.x;
    int source = (span.x + width - c->offset) % width, left = span.width;
    while (left) {
        if (!source) {
            compose_alpha_run_scalar(dest++, row, row + width - 1, 1, c);
            source = width > 1 ? 1 : 0;
            left--;
            continue;
        }
        int count = width - source < left ? width - source : left;
        if (use_avx2) compose_alpha_run_avx2(dest, row + source, row + source - 1, count, c);
        else compose_alpha_run_scalar(dest, row + source, row + source - 1, count, c);
        dest += count;
        left -= count;
        source = (source + count) % width;
    }
}

static void compose_sky_keyframe(double t) {
    bool dirty[cloud_height];
    memset(dirty, 0, sizeof(dirty));
    bool changed = false;
    int offsets[MAX_CLOUDS];
    unsigned fractions[MAX_CLOUDS];
    unsigned breath = (unsigned)lround((0.5 + 0.5 * sin(TAU * t / 72)) * 255);
    for (int i = 0; i < cloud_count; i++) {
        struct cloud *c = &clouds[i];
        double position = fmod(t * c->speed, width);
        offsets[i] = (int)floor(position);
        fractions[i] = (unsigned)lround((position - offsets[i]) * 256);
        if (fractions[i] == 256) {
            offsets[i] = (offsets[i] + 1) % width;
            fractions[i] = 0;
        }
        if (offsets[i] == c->offset && fractions[i] == c->fraction &&
            (c->kind != 'G' || c->breath == (int)breath)) continue;
        changed = true;
        memset(dirty + c->y - cloud_y, 1, (size_t)c->height);
    }
    if (!changed) return;
    for (int i = 0; i < cloud_count; i++) {
        struct cloud *c = &clouds[i];
        c->offset = offsets[i];
        c->fraction = fractions[i];
        c->breath = (int)breath;
    }
    /* Expensive layer composition runs at 2 Hz, not at the display rate.
     * Subpixel samples wrap, while destination masks stay fixed. */
    for (int row = 0; row < cloud_height; row++)
        if (dirty[row]) memcpy(cloud_background + row * width,
            base + (row + cloud_y) * width, (size_t)width * 4);
    for (int i = 0; i < cloud_count; i++) {
        const struct cloud *c = &clouds[i];
        for (int s = 0; s < c->span_count; s++) {
            struct span span = c->spans[s];
            int y = span.y - c->y, row = span.y - cloud_y;
            if (!dirty[row]) continue;
            if (c->kind == 'A') {
                compose_alpha_span(c, span);
                continue;
            }
            int source = (span.x + width - c->offset) % width;
            for (int x = span.x; x < span.x + span.width; x++) {
                int source_x = source;
                int neighbor_x = source_x ? source_x - 1 : width - 1;
                if (++source == width) source = 0;
                uint32_t *pixel = cloud_background + row * width + x, v = *pixel;
                if (c->kind == 'G') {
                    /* The two halo widths never move. Only a terrain-free
                     * modulation field drifts, gently varying width/brightness. */
                    const uint8_t *masks = c->data + (y * width + x) * 3;
                    unsigned modulation = c->data[(y * width + source_x) * 3 + 2];
                    if (c->fraction)
                        modulation = (modulation * (256 - c->fraction) +
                            c->data[(y * width + neighbor_x) * 3 + 2] * c->fraction + 128) >> 8;
                    unsigned a = glow_opacity(masks[0], masks[1], modulation, breath);
                    unsigned r = clamp_channel((int)((v >> 16) & 255) + (int)((c->r * a + 127) / 255));
                    unsigned g = clamp_channel((int)((v >> 8) & 255) + (int)((c->g * a + 127) / 255));
                    unsigned b = clamp_channel((int)(v & 255) + (int)((c->b * a + 127) / 255));
                    *pixel = 0xff000000u | (r << 16) | (g << 8) | b;
                    continue;
                }
                if (c->kind == 'P') {
                    /* Move the original signed colour detail, not the glow or
                     * silhouette. The destination mask must NOT scroll. */
                    unsigned mask = c->data[(y * width + x) * 4 + 3];
                    const int8_t *detail = (const int8_t *)(c->data + (y * width + source_x) * 4);
                    const int8_t *neighbor = (const int8_t *)(c->data + (y * width + neighbor_x) * 4);
                    unsigned r = clamp_channel((int)((v >> 16) & 255) + sampled_detail_offset(detail[0], neighbor[0], c->fraction, mask));
                    unsigned g = clamp_channel((int)((v >> 8) & 255) + sampled_detail_offset(detail[1], neighbor[1], c->fraction, mask));
                    unsigned b = clamp_channel((int)(v & 255) + sampled_detail_offset(detail[2], neighbor[2], c->fraction, mask));
                    *pixel = 0xff000000u | (r << 16) | (g << 8) | b;
                    continue;
                }
            }
        }
    }
}

static void update_clouds(double t) {
    bool initial = sky_keyframe < 0;
    if (!initial && !moving_sky) return;
    int64_t key = (int64_t)floor(t / SKY_KEYFRAME_SECONDS);
    double start = key * SKY_KEYFRAME_SECONDS;
    unsigned blend = (unsigned)lround((t - start) / SKY_KEYFRAME_SECONDS * 256);
    if (initial || key != sky_keyframe) {
        size_t size = (size_t)width * cloud_height * 4;
        if (initial || key != sky_keyframe + 1) compose_sky_keyframe(start);
        memcpy(previous_sky, cloud_background, size);
        compose_sky_keyframe(start + SKY_KEYFRAME_SECONDS);
    } else if (blend == sky_blend) return;
    sky_keyframe = key;
    sky_blend = blend;
    cloud_serial++;
    for (int i = 0; i < cloud_count; i++)
        if (initial || clouds[i].speed > 0 || clouds[i].kind == 'G') clouds[i].serial = cloud_serial;
}

static uint32_t blended_pixel(uint32_t a, uint32_t b, unsigned weight) {
    unsigned inverse = 256 - weight;
    uint32_t rb = (((a & 0x00ff00ffu) * inverse + (b & 0x00ff00ffu) * weight + 0x00800080u) >> 8) & 0x00ff00ffu;
    uint32_t g = ((((a >> 8) & 255) * inverse + ((b >> 8) & 255) * weight + 128) & 0x0000ff00u);
    return 0xff000000u | rb | g;
}

static void interpolate_row_sse2(uint32_t *dest, const uint32_t *a, const uint32_t *b, int count) {
    /* SSE2 is baseline on this x86_64 machine. Blend four pixels at a time;
     * no full-frame copies, optical-flow model or extra animation library. */
    __m128i wa = _mm_set1_epi16((short)(256 - sky_blend));
    __m128i wb = _mm_set1_epi16((short)sky_blend);
    __m128i zero = _mm_setzero_si128(), round = _mm_set1_epi16(128);
    int x = 0;
    for (; x + 4 <= count; x += 4) {
        __m128i aa = _mm_loadu_si128((const __m128i *)(a + x));
        __m128i bb = _mm_loadu_si128((const __m128i *)(b + x));
        __m128i lo = _mm_add_epi16(_mm_mullo_epi16(_mm_unpacklo_epi8(aa, zero), wa),
                                  _mm_mullo_epi16(_mm_unpacklo_epi8(bb, zero), wb));
        __m128i hi = _mm_add_epi16(_mm_mullo_epi16(_mm_unpackhi_epi8(aa, zero), wa),
                                  _mm_mullo_epi16(_mm_unpackhi_epi8(bb, zero), wb));
        lo = _mm_srli_epi16(_mm_add_epi16(lo, round), 8);
        hi = _mm_srli_epi16(_mm_add_epi16(hi, round), 8);
        _mm_storeu_si128((__m128i *)(dest + x), _mm_packus_epi16(lo, hi));
    }
    for (; x < count; x++) dest[x] = blended_pixel(a[x], b[x], sky_blend);
}

__attribute__((target("avx2")))
static void interpolate_row_avx2(uint32_t *dest, const uint32_t *a, const uint32_t *b, int count) {
    __m256i wa = _mm256_set1_epi16((short)(256 - sky_blend));
    __m256i wb = _mm256_set1_epi16((short)sky_blend);
    __m256i zero = _mm256_setzero_si256(), round = _mm256_set1_epi16(128);
    int x = 0;
    for (; x + 8 <= count; x += 8) {
        __m256i aa = _mm256_loadu_si256((const __m256i *)(a + x));
        __m256i bb = _mm256_loadu_si256((const __m256i *)(b + x));
        __m256i lo = _mm256_add_epi16(_mm256_mullo_epi16(_mm256_unpacklo_epi8(aa, zero), wa),
                                     _mm256_mullo_epi16(_mm256_unpacklo_epi8(bb, zero), wb));
        __m256i hi = _mm256_add_epi16(_mm256_mullo_epi16(_mm256_unpackhi_epi8(aa, zero), wa),
                                     _mm256_mullo_epi16(_mm256_unpackhi_epi8(bb, zero), wb));
        lo = _mm256_srli_epi16(_mm256_add_epi16(lo, round), 8);
        hi = _mm256_srli_epi16(_mm256_add_epi16(hi, round), 8);
        _mm256_storeu_si256((__m256i *)(dest + x), _mm256_packus_epi16(lo, hi));
    }
    for (; x < count; x++) dest[x] = blended_pixel(a[x], b[x], sky_blend);
}

static void interpolate_row(uint32_t *dest, const uint32_t *a, const uint32_t *b, int count) {
    if (!sky_blend || sky_blend == 256) {
        memcpy(dest, sky_blend ? b : a, (size_t)count * 4);
        return;
    }
    if (use_avx2) interpolate_row_avx2(dest, a, b, count);
    else interpolate_row_sse2(dest, a, b, count);
}

/* Destination support never scrolls. Cache its runs once so neither keyframe
 * composition nor display-rate restoration scans through mountain interiors. */
static struct span *support_spans(const uint8_t *mask, int y0, int rows, int *count) {
    *count = 0;
    for (int y = 0; y < rows; y++) for (int x = 0; x < width; x++)
        if (mask[y * width + x] && (!x || !mask[y * width + x - 1])) (*count)++;
    if (!*count) return NULL;
    struct span *spans = malloc((size_t)*count * sizeof(*spans));
    if (!spans) fail("cannot allocate sky support spans");
    int n = 0;
    for (int y = 0; y < rows; y++) for (int x = 0; x < width;) {
        if (!mask[y * width + x]) { x++; continue; }
        int start = x++;
        while (x < width && mask[y * width + x]) x++;
        spans[n++] = (struct span){start, y + y0, x - start};
    }
    return spans;
}

static void load_clouds(const char *directory) {
    char *path;
    if (asprintf(&path, "%s/clouds.txt", directory) < 0) fail("out of memory");
    FILE *f = fopen(path, "r");
    free(path);
    int w, h;
    if (!f || fscanf(f, "CLOUDS2 %d %d %d %d %d", &w, &h, &cloud_y,
        &cloud_height, &cloud_count) != 5 || w != width || h != height ||
        cloud_y < 0 || cloud_height < 1 || cloud_height > height - cloud_y ||
        cloud_count < 1 || cloud_count > MAX_CLOUDS) fail("invalid clouds.txt");
    for (int i = 0; i < cloud_count; i++) {
        struct cloud *c = &clouds[i];
        if (fscanf(f, " %c %d %d %lf %u %u %u", &c->kind, &c->y, &c->height, &c->speed,
            &c->r, &c->g, &c->b) != 7 || !strchr("APG", c->kind) || c->y < cloud_y || c->height < 1 ||
            c->height > cloud_y + cloud_height - c->y || !isfinite(c->speed) ||
            c->speed < 0 || c->speed > 4 || c->r > 255 || c->g > 255 || c->b > 255)
            fail("invalid cloud strip");
        layer_data_size += (size_t)c->height * width * layer_stride(c->kind);
        c->offset = -1;
        c->breath = -1;
        if (c->speed > 0 || c->kind == 'G') moving_sky = true;
    }
    fclose(f);
    layer_data = map_asset(directory, "clouds.bin", layer_data_size);
    size_t offset = 0;
    for (int i = 0; i < cloud_count; i++) {
        clouds[i].data = layer_data + offset;
        offset += (size_t)clouds[i].height * width * layer_stride(clouds[i].kind);
    }
    size_t size = (size_t)width * cloud_height;
    sky_mask = map_asset(directory, "sky.a8", size);
    int cols = (output_width + DAMAGE_WIDTH - 1) / DAMAGE_WIDTH;
    int rows = (height + DAMAGE_HEIGHT - 1) / DAMAGE_HEIGHT;
    uint8_t *support = malloc(size), *combined = calloc(size, 1);
    if (!support || !combined) fail("cannot allocate sky support mask");
    for (int i = 0; i < cloud_count; i++) {
        struct cloud *c = &clouds[i];
        c->damage_tiles = calloc((size_t)output_count * rows * cols, 1);
        if (!c->damage_tiles) fail("cannot allocate sky damage mask");
        for (int y = 0; y < c->height; y++) for (int x = 0; x < width; x++) {
            bool active = sky_mask[(c->y + y - cloud_y) * width + x] != 0;
            if (c->kind == 'P')
                active = active && c->data[(y * width + x) * 4 + 3];
            else if (c->kind == 'G') {
                const uint8_t *masks = c->data + (y * width + x) * 3;
                active = (masks[0] | masks[1]) != 0;
            }
            support[y * width + x] = active;
            if (!active) continue;
            combined[(c->y + y - cloud_y) * width + x] = 1;
            int output = x / output_width, tx = (x % output_width) / DAMAGE_WIDTH;
            int ty = (c->y + y) / DAMAGE_HEIGHT;
            c->damage_tiles[(output * rows + ty) * cols + tx] = 1;
        }
        c->spans = support_spans(support, c->y, c->height, &c->span_count);
    }
    sky_spans = support_spans(combined, cloud_y, cloud_height, &sky_span_count);
    free(support);
    free(combined);
    cloud_background = malloc(size * 4);
    previous_sky = malloc(size * 4);
    if (!cloud_background || !previous_sky) fail("cannot allocate sky keyframes");
    memcpy(cloud_background, base + cloud_y * width, size * 4);
    update_clouds(0);
}

static struct rect clip(struct output *o, int x, int y, int w, int h) {
    int left = o->index * output_width;
    int x0 = x > left ? x : left, y0 = y > 0 ? y : 0;
    int x1 = x + w < left + output_width ? x + w : left + output_width;
    int y1 = y + h < height ? y + h : height;
    return (struct rect){x0 - left, y0, x1 - x0, y1 - y0};
}

static void restore(struct output *o, struct buffer *b, struct rect r) {
    for (int y = r.y; y < r.y + r.h; y++) {
        int x = o->index * output_width + r.x;
        uint32_t *dest = b->pixels + y * output_width + r.x;
        if (y >= cloud_y && y < cloud_y + cloud_height) {
            int offset = (y - cloud_y) * width + x;
            interpolate_row(dest, previous_sky + offset, cloud_background + offset, r.w);
        } else memcpy(dest, base + y * width + x, (size_t)r.w * 4);
        apply_film_row(dest, r.w, x, y);
    }
}

static void pixel(struct output *o, struct buffer *b, const struct effect *e,
                  int x, int y, double alpha) {
    x -= o->index * output_width;
    if (x < 0 || x >= output_width || y < 0 || y >= height) return;
    if (alpha < 0.002) return;
    if (alpha > 1) alpha = 1;
    uint32_t *p = b->pixels + y * output_width + x, v = *p;
    unsigned r = ((v >> 16) & 255) * (1 - alpha) + e->r * 255 * alpha;
    unsigned g = ((v >> 8) & 255) * (1 - alpha) + e->g * 255 * alpha;
    unsigned bl = (v & 255) * (1 - alpha) + e->b * 255 * alpha;
    *p = 0xff000000u | (r << 16) | (g << 8) | bl;
}

static void detail(struct output *o, struct buffer *b, const struct effect *e, double t) {
    double cycle = t * e->rate + e->phase;
    cycle -= floor(cycle);
    double pulse = sin(cycle * TAU / 2), alpha = e->strength;
    int x = lround(e->x), y = lround(e->y), length = 0;
    struct rect r;
    switch (e->kind) {
    case 'S':
        alpha *= 1 - e->depth * (0.5 + 0.5 * sin(cycle * TAU));
        length = lround(e->length);
        r = clip(o, x - length, y - length, length * 2 + 1, length * 2 + 1);
        break;
    case 'R':
        alpha *= pulse * pulse;
        x += lround(sin(t * 0.38 + e->phase * TAU) * e->length * 0.45);
        y += lround((cycle - 0.5) * 12);
        length = lround(e->length * (0.45 + 0.55 * cycle));
        r = clip(o, x - length, y - 1, length * 2 + 1, 5);
        break;
    case 'F':
        alpha *= pow(fmax(0, sin(cycle * TAU)), 2);
        x += lround(sin(t * 0.45 + e->phase * TAU) * e->length);
        y += lround(sin(t * 0.35 + e->phase * TAU) * 8);
        length = 3;
        r = clip(o, x - length, y - length, length * 2 + 1, length * 2 + 1);
        break;
    default: /* Brief shooting stars, independently spaced 47 and 61 seconds apart. */
        if (cycle > e->rate * 2.1) return;
        cycle /= e->rate * 2.1;
        alpha *= sin(cycle * TAU / 2);
        x += lround(e->length * cycle);
        y += lround(e->length * cycle * 0.28);
        length = lround(e->length * 0.30);
        r = clip(o, x - length - 1, y - (int)ceil(length * 0.28) - 1, length + 3,
                 (int)ceil(length * 0.28) + 3);
        break;
    }
    if (alpha < 0.004 || r.w <= 0 || r.h <= 0) return;
    b->rects[b->count++] = r;
    if (e->kind == 'S' || e->kind == 'F') {
        pixel(o, b, e, x, y, alpha);
        for (int d = 1; d <= length; d++) {
            double glow = alpha * (e->kind == 'F' ? exp(-0.4 * d * d) : 0.45 / (d * d));
            pixel(o, b, e, x + d, y, glow);
            pixel(o, b, e, x - d, y, glow);
            pixel(o, b, e, x, y + d, glow);
            pixel(o, b, e, x, y - d, glow);
        }
        if (length >= 2)
            for (int dx = -1; dx <= 1; dx += 2)
                for (int dy = -1; dy <= 1; dy += 2)
                    pixel(o, b, e, x + dx, y + dy, alpha * 0.15);
    } else if (e->kind == 'R') {
        for (int dx = -length; dx <= length; dx++) {
            double taper = 1 - fabs((double)dx) / (length + 1);
            int bend = abs(dx) > length * 0.65 ? 1 : 0;
            pixel(o, b, e, x + dx, y + bend, alpha * taper);
            pixel(o, b, e, x + dx, y + bend + 1, alpha * taper * 0.18);
            pixel(o, b, e, x + dx / 2, y + 3, alpha * taper * 0.28);
        }
    } else {
        for (int d = 0; d <= length; d++) {
            double tail = alpha * (1 - (double)d / (length + 1));
            int yy = y - lround(d * 0.28);
            pixel(o, b, e, x - d, yy, tail);
            pixel(o, b, e, x - d, yy + 1, tail * 0.25);
        }
        pixel(o, b, e, x + 1, y, alpha * 0.3);
        pixel(o, b, e, x, y - 1, alpha * 0.3);
    }
}

static void paint(struct output *o, struct buffer *b, double t) {
    if (film_enabled && (!b->initialized || b->film_epoch != film_epoch)) {
        struct buffer *other = b == &o->buffers[0] ? &o->buffers[1] : &o->buffers[0];
        if (other->initialized && other->film_epoch == film_epoch) {
            /* Reuse the other buffer's finished emulsion for static pixels;
             * regenerate only the changing sky/sprite rectangles below. */
            memcpy(b->pixels, other->pixels, (size_t)output_width * height * 4);
            b->count = other->count;
            memcpy(b->rects, other->rects, (size_t)other->count * sizeof(struct rect));
            b->cloud_serial = other->cloud_serial;
        } else {
            restore(o, b, (struct rect){0, 0, output_width, height});
            b->count = 0;
            b->cloud_serial = cloud_serial;
        }
        b->film_epoch = film_epoch;
    }
    for (int i = 0; i < b->count; i++) restore(o, b, b->rects[i]);
    bool dirty[cloud_height];
    memset(dirty, 0, sizeof(dirty));
    for (int i = 0; i < cloud_count; i++) {
        const struct cloud *c = &clouds[i];
        if (c->serial > b->cloud_serial)
            memset(dirty + c->y - cloud_y, 1, (size_t)c->height);
    }
    for (int i = 0; i < sky_span_count; i++) {
        struct span span = sky_spans[i];
        if (!dirty[span.y - cloud_y]) continue;
        struct rect r = clip(o, span.x, span.y, span.width, 1);
        if (r.w > 0) restore(o, b, r);
    }
    b->cloud_serial = cloud_serial;
    b->count = 0;
    for (int i = 0; i < effect_count; i++) detail(o, b, &effects[i], t);
    b->initialized = true;
}

static void buffer_release(void *data, struct wl_buffer *wl) {
    ((struct buffer *)data)->busy = false;
}
static const struct wl_buffer_listener buffer_listener = { .release = buffer_release };

static void allocate_buffer(struct output *o, struct buffer *b) {
    size_t size = (size_t)output_width * height * 4;
    int fd = memfd_create("twilight-wallpaper", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, size)) fail("cannot allocate shared buffer");
    b->pixels = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (b->pixels == MAP_FAILED) fail("cannot map shared buffer");
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, size);
    b->wl = wl_shm_pool_create_buffer(pool, 0, output_width, height,
                                    output_width * 4, WL_SHM_FORMAT_XRGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);
    wl_buffer_add_listener(b->wl, &buffer_listener, b);
    restore(o, b, (struct rect){0, 0, output_width, height});
    b->cloud_serial = cloud_serial;
}

static void frame_done(void *data, struct wl_callback *callback, uint32_t time) {
    struct output *o = data;
    wl_callback_destroy(callback);
    o->frame = NULL;
}
static const struct wl_callback_listener frame_listener = { .done = frame_done };

static void mark_damage(struct output *o, struct buffer *b, int cols, int rows, bool *dirty) {
    memset(dirty, 0, (size_t)rows * cols * sizeof(*dirty));
    for (int i = 0; i < o->count + b->count + cloud_count; i++) {
        struct rect r;
        if (i < o->count) r = o->previous[i];
        else if (i < o->count + b->count) r = b->rects[i - o->count];
        else {
            const struct cloud *c = &clouds[i - o->count - b->count];
            if (c->serial <= o->cloud_serial) continue;
            if (c->damage_tiles) {
                for (int y = 0; y < rows; y++) for (int x = 0; x < cols; x++)
                    if (c->damage_tiles[(o->index * rows + y) * cols + x]) dirty[y * cols + x] = true;
                continue;
            }
            r = (struct rect){0, c->y, output_width, c->height};
        }
        for (int y = r.y / DAMAGE_HEIGHT; y <= (r.y + r.h - 1) / DAMAGE_HEIGHT; y++)
            for (int x = r.x / DAMAGE_WIDTH; x <= (r.x + r.w - 1) / DAMAGE_WIDTH; x++) dirty[y * cols + x] = true;
    }
}

static void damage_details(struct output *o, struct buffer *b) {
    /* Hundreds of individual 1px damage requests make the compositor spend
     * more CPU on regions/texture-upload calls than on drawing. Batch nearby
     * details into small tiles; copying a little unchanged paint is cheaper. */
    enum { TW = DAMAGE_WIDTH, TH = DAMAGE_HEIGHT };
    int cols = (output_width + TW - 1) / TW, rows = (height + TH - 1) / TH;
    bool dirty[rows][cols];
    mark_damage(o, b, cols, rows, &dirty[0][0]);
    for (int y = 0; y < rows; y++) for (int x = 0; x < cols; x++) {
        if (!dirty[y][x]) continue;
        int right = x + 1, bottom = y + 1;
        while (right < cols && dirty[y][right]) right++;
        while (bottom < rows) {
            bool full = true;
            for (int xx = x; xx < right; xx++) if (!dirty[bottom][xx]) full = false;
            if (!full) break;
            bottom++;
        }
        for (int yy = y; yy < bottom; yy++)
            for (int xx = x; xx < right; xx++) dirty[yy][xx] = false;
        int x1 = right * TW < output_width ? right * TW : output_width;
        int y1 = bottom * TH < height ? bottom * TH : height;
        wl_surface_damage_buffer(o->surface, x * TW, y * TH, x1 - x * TW, y1 - y * TH);
    }
}

static void remember_frame(struct output *o, struct buffer *b) {
    o->count = b->count;
    o->cloud_serial = cloud_serial;
    o->film_epoch = film_epoch;
    memcpy(o->previous, b->rects, (size_t)b->count * sizeof(struct rect));
}

static void submit(struct output *o, struct buffer *b, double t) {
    paint(o, b, t);
    if (!o->painted || (film_enabled && o->film_epoch != film_epoch)) {
        wl_surface_damage_buffer(o->surface, 0, 0, output_width, height);
        o->painted = true;
    } else {
        /* Also damage the last DISPLAYED positions, not just this buffer's
         * two-frames-old positions, or moving sprites leave trails. */
        damage_details(o, b);
    }
    remember_frame(o, b);
    o->frame = wl_surface_frame(o->surface);
    wl_callback_add_listener(o->frame, &frame_listener, o);
    b->busy = true;
    wl_surface_attach(o->surface, b->wl, 0, 0);
    wl_surface_commit(o->surface);
}

static void destroy_output(struct output *o) {
    if (o->frame) wl_callback_destroy(o->frame);
    if (o->layer) zwlr_layer_surface_v1_destroy(o->layer);
    if (o->surface) wl_surface_destroy(o->surface);
    for (int i = 0; i < 2; i++) {
        if (o->buffers[i].wl) wl_buffer_destroy(o->buffers[i].wl);
        if (o->buffers[i].pixels)
            munmap(o->buffers[i].pixels, (size_t)output_width * height * 4);
    }
    if (o->wl) wl_output_release(o->wl);
    memset(o, 0, sizeof(*o));
}

static void configure(void *data, struct zwlr_layer_surface_v1 *layer,
                      uint32_t serial, uint32_t w, uint32_t h) {
    struct output *o = data;
    zwlr_layer_surface_v1_ack_configure(layer, serial);
    if ((w && w != (uint32_t)output_width) || (h && h != (uint32_t)height))
        fail("output size changed; regenerate the scene for the new monitor layout");
    if (!o->configured) {
        allocate_buffer(o, &o->buffers[0]);
        allocate_buffer(o, &o->buffers[1]);
        o->configured = true;
    }
}
static void closed(void *data, struct zwlr_layer_surface_v1 *layer) {
    destroy_output(data);
}
static const struct zwlr_layer_surface_v1_listener layer_listener = {
    .configure = configure, .closed = closed,
};

static void start_output(struct output *o) {
    if (!globals_ready || o->index < 0 || o->surface) return;
    o->surface = wl_compositor_create_surface(compositor);
    struct wl_region *region = wl_compositor_create_region(compositor);
    wl_surface_set_input_region(o->surface, region); /* Click-through. */
    wl_region_add(region, 0, 0, output_width, height);
    wl_surface_set_opaque_region(o->surface, region);
    wl_region_destroy(region);
    o->layer = zwlr_layer_shell_v1_get_layer_surface(shell, o->surface, o->wl,
        ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND, "twilight-wallpaper");
    zwlr_layer_surface_v1_add_listener(o->layer, &layer_listener, o);
    zwlr_layer_surface_v1_set_anchor(o->layer, 15); /* All four edges. */
    zwlr_layer_surface_v1_set_exclusive_zone(o->layer, -1);
    zwlr_layer_surface_v1_set_keyboard_interactivity(o->layer, 0);
    wl_surface_commit(o->surface);
}

static void output_geometry(void *d, struct wl_output *o, int32_t x, int32_t y,
    int32_t pw, int32_t ph, int32_t sub, const char *make, const char *model, int32_t tr) {}
static void output_mode(void *d, struct wl_output *o, uint32_t flags, int32_t w,
                        int32_t h, int32_t refresh) {}
static void output_scale(void *d, struct wl_output *o, int32_t scale) {}
static void output_description(void *d, struct wl_output *o, const char *description) {}
static void output_done(void *data, struct wl_output *wl) { start_output(data); }
static void output_name(void *data, struct wl_output *wl, const char *name) {
    struct output *o = data;
    for (int i = 0; i < output_count; i++)
        if (!strcmp(name, output_names[i])) o->index = i;
}
static const struct wl_output_listener output_listener = {
    .geometry = output_geometry, .mode = output_mode, .done = output_done,
    .scale = output_scale, .name = output_name, .description = output_description,
};

static void global(void *data, struct wl_registry *registry, uint32_t id,
                   const char *interface, uint32_t version) {
    if (!strcmp(interface, "wl_compositor") && version >= 4)
        compositor = wl_registry_bind(registry, id, &wl_compositor_interface, 4);
    else if (!strcmp(interface, "wl_shm"))
        shm = wl_registry_bind(registry, id, &wl_shm_interface, 1);
    else if (!strcmp(interface, "zwlr_layer_shell_v1"))
        shell = wl_registry_bind(registry, id, &zwlr_layer_shell_v1_interface, 1);
    else if (!strcmp(interface, "wl_output") && version >= 4)
        for (int i = 0; i < MAX_OUTPUTS; i++) {
            struct output *o = &outputs[i];
            if (o->id) continue;
            o->id = id;
            o->index = -1;
            o->wl = wl_registry_bind(registry, id, &wl_output_interface, 4);
            wl_output_add_listener(o->wl, &output_listener, o);
            break;
        }
}
static void global_remove(void *data, struct wl_registry *registry, uint32_t id) {
    for (int i = 0; i < MAX_OUTPUTS; i++)
        if (outputs[i].id == id) destroy_output(&outputs[i]);
}
static const struct wl_registry_listener registry_listener = {
    .global = global, .global_remove = global_remove,
};
static void signal_handler(int signal) {
    if (signal == SIGUSR1) paused = !paused;
    else running = 0;
}

static struct buffer *available(struct output *o) {
    for (int i = 0; i < 2; i++) if (!o->buffers[i].busy) return &o->buffers[i];
    return NULL;
}

__attribute__((target("avx2")))
static void check_divide255(void) {
    uint16_t input[16], actual[16];
    for (unsigned value = 0; value <= 65152; value += 16) {
        for (unsigned i = 0; i < 16; i++) input[i] = value + i > 65152 ? 65152 : value + i;
        __m256i pixels = _mm256_loadu_si256((const __m256i *)input);
        _mm256_storeu_si256((__m256i *)actual, divide255_16(pixels));
        for (int i = 0; i < 16; i++)
            if (actual[i] != input[i] / 255) fail("SIMD /255 rounding regression");
    }
}

static void check_alpha_composition(void) {
    if (use_avx2) check_divide255();
    uint32_t input[37], expected[37], actual[37];
    uint8_t source[37], neighbor[37];
    for (int i = 0; i < 37; i++) input[i] = 0xff000000u | ((uint32_t)i * 104729u & 0x00ffffffu);
    input[0] = 0xffffffffu;
    input[1] = 0xff000000u;
    input[2] = 0xffff0000u;
    input[3] = 0xff00ff00u;
    input[4] = 0xff0000ffu;
    const unsigned tints[][3] = {{0, 0, 0}, {255, 255, 255}, {41, 173, 239}};
    for (int pattern = 0; pattern < 3; pattern++) {
        for (int i = 0; i < 37; i++) {
            source[i] = pattern == 0 ? 0 : pattern == 1 ? 255 : (i * 197 + 31) & 255;
            neighbor[i] = pattern == 0 ? 255 : pattern == 1 ? 0 : (i * 97 + 239) & 255;
        }
        for (int tint = 0; tint < 3; tint++) for (unsigned fraction = 0; fraction <= 256; fraction++) {
            struct cloud c = {.fraction = fraction, .r = tints[tint][0], .g = tints[tint][1], .b = tints[tint][2]};
            for (int n = 1; n <= 37; n++) {
                memcpy(expected, input, sizeof(input));
                memcpy(actual, input, sizeof(input));
                compose_alpha_run_scalar(expected, source, neighbor, n, &c);
                if (use_avx2) compose_alpha_run_avx2(actual, source, neighbor, n, &c);
                else compose_alpha_run_scalar(actual, source, neighbor, n, &c);
                if (memcmp(actual, expected, sizeof(actual))) fail("alpha SIMD/scalar or tail regression");
            }
        }
    }
}

static void check_interpolation(void) {
    uint32_t a[35], b[35], actual[35], fallback[35];
    for (int i = 0; i < 35; i++) {
        a[i] = 0xff000000u | ((uint32_t)i * 7919u & 0x00ffffffu);
        b[i] = 0xff000000u | ((uint32_t)(35 - i) * 104729u & 0x00ffffffu);
    }
    unsigned saved = sky_blend;
    for (unsigned f = 0; f <= 256; f++) for (int n = 1; n <= 35; n++) {
        sky_blend = f;
        interpolate_row(actual, a, b, n);
        interpolate_row_sse2(fallback, a, b, n);
        if (memcmp(actual, fallback, (size_t)n * 4)) fail("AVX2/SSE2 interpolation regression");
        for (int i = 0; i < n; i++) {
            uint32_t expected = 0;
            for (int shift = 0; shift <= 24; shift += 8) {
                unsigned av = (a[i] >> shift) & 255, bv = (b[i] >> shift) & 255;
                expected |= ((av * (256 - f) + bv * f + 128) >> 8) << shift;
            }
            if (actual[i] != expected) fail("SIMD/scalar interpolation regression");
        }
    }
    sky_blend = saved;
    if (sampled_detail_offset(-20, 20, 128, 255) != 0 ||
        sampled_detail_offset(-20, 20, 0, 255) != -20 ||
        sampled_detail_offset(-20, 20, 256, 255) != 20)
        fail("signed subpixel sampling regression");
    for (unsigned phase = 0; phase <= 255; phase++)
        for (unsigned breath = 0; breath <= 255; breath++)
            if (glow_opacity(0, 0, phase, breath)) fail("glow escaped its support");
    if (glow_opacity(70, 70, 0, 0) >= glow_opacity(70, 70, 255, 255) ||
        glow_opacity(0, 70, 0, 0) >= glow_opacity(0, 70, 255, 255))
        fail("glow brightness/softness modulation regression");
}

static void check_film(void) {
    if (!film_enabled) return;
    const int xs[] = {0, 1, 509, 510, 511, 1918, 1920, 3830};
    const int ys[] = {0, 17, 511, 512, 1079};
    uint32_t input[37], expected[37], actual[37];
    for (int i = 0; i < 37; i++) input[i] = 0xff000000u | ((uint32_t)i * 104729u & 0x00ffffffu);
    input[1] = 0xffffffffu;
    input[2] = 0xffff0000u;
    input[3] = 0xff00ff00u;
    input[4] = 0xff0000ffu;
    for (int frame = 0; frame < 4; frame++) {
        update_film(frame * 123.125);
        for (size_t yy = 0; yy < sizeof(ys) / sizeof(*ys); yy++)
        for (size_t xx = 0; xx < sizeof(xs) / sizeof(*xs); xx++)
        for (int n = 1; n <= 37; n++) {
            int x = xs[xx], y = ys[yy];
            const int8_t *row = film_noise + ((y + (film_phase >> 9)) & (GRAIN_SIDE - 1)) * GRAIN_STRIDE;
            memcpy(actual, input, (size_t)n * 4);
            for (int i = 0; i < n; i++) {
                unsigned shift = film_phase + (unsigned)((x + i) / GRAIN_SIDE) * 211u + (unsigned)(y / GRAIN_SIDE) * 97u;
                expected[i] = film_pixel(input[i], row[(x + i + shift) & (GRAIN_SIDE - 1)]);
            }
            apply_film_row(actual, n, x, y);
            if (memcmp(actual, expected, (size_t)n * 4)) fail("film SIMD/scalar or tile-wrap regression");
            memcpy(actual, input, (size_t)n * 4);
            apply_film_row_sse2(actual, n, x, y);
            if (memcmp(actual, expected, (size_t)n * 4)) fail("film SSE2/scalar regression");
            if (film_pixel(0xff000000u, 112) != 0xff000000u) fail("film pass lifted pure black");
        }
    }
    update_film(0);
    uint32_t first = film_phase;
    update_film(0.75 / grain_fps);
    if (film_phase != first) fail("film grain refreshed too early");
    update_film(1 / grain_fps);
    if (film_phase == first) fail("film grain did not advance");
    update_film(0);
}

static void check_glow_anchor(struct output *o, struct buffer *reference) {
    bool present = false, changed = false;
    double speeds[MAX_CLOUDS];
    for (int i = 0; i < cloud_count; i++) {
        speeds[i] = clouds[i].speed;
        if (clouds[i].kind == 'G') present = true;
    }
    if (!present) return;
    for (int i = 0; i < cloud_count; i++)
        if (clouds[i].kind != 'G') clouds[i].speed = 0;
    for (int index = 0; index < output_count; index++) {
        o->index = index;
        sky_keyframe = -1;
        update_clouds(0);
        restore(o, &o->buffers[0], (struct rect){0, 0, output_width, height});
        update_clouds(757.25);
        restore(o, reference, (struct rect){0, 0, output_width, height});
        for (int y = 0; y < height; y++) for (int x = 0; x < output_width; x++) {
            int pixel = y * output_width + x;
            if (o->buffers[0].pixels[pixel] == reference->pixels[pixel]) continue;
            changed = true;
            bool supported = false;
            for (int i = 0; i < cloud_count; i++) {
                const struct cloud *c = &clouds[i];
                if (c->kind != 'G' || y < c->y || y >= c->y + c->height) continue;
                int source = ((y - c->y) * width + index * output_width + x) * 3;
                if (c->data[source] || c->data[source + 1]) supported = true;
            }
            if (!supported) fail("ridge glow moved outside its fixed mask");
        }
    }
    for (int i = 0; i < cloud_count; i++) clouds[i].speed = speeds[i];
    sky_keyframe = -1;
    update_clouds(0);
    o->index = 0;
    if (!changed) fail("ridge glow failed to evolve");
}

/* Headless regression check: alternating buffers must exactly match a freshly
 * rendered frame, including overlapping details and the rare meteor path. */
static void check_damage(struct output *o, struct buffer *b, const uint32_t *previous) {
    if (film_enabled && o->film_epoch != film_epoch) return; /* Full damage. */
    int cols = (output_width + DAMAGE_WIDTH - 1) / DAMAGE_WIDTH;
    int rows = (height + DAMAGE_HEIGHT - 1) / DAMAGE_HEIGHT;
    bool dirty[rows][cols];
    mark_damage(o, b, cols, rows, &dirty[0][0]);
    for (int y = 0; y < height; y++) for (int x = 0; x < output_width; x += DAMAGE_WIDTH) {
        if (dirty[y / DAMAGE_HEIGHT][x / DAMAGE_WIDTH]) continue;
        int count = output_width - x < DAMAGE_WIDTH ? output_width - x : DAMAGE_WIDTH;
        int offset = y * output_width + x;
        if (memcmp(b->pixels + offset, previous + offset, (size_t)count * 4))
            fail("changed pixel outside compositor damage");
    }
}

static void check_scene(void) {
    check_interpolation();
    check_alpha_composition();
    check_film();
    struct output *o = calloc(1, sizeof(*o));
    struct buffer *reference = calloc(1, sizeof(*reference));
    if (!o || !reference) fail("out of memory");
    size_t size = (size_t)output_width * height * 4;
    reference->pixels = malloc(size);
    for (int j = 0; j < 2; j++) o->buffers[j].pixels = malloc(size);
    if (!reference->pixels || !o->buffers[0].pixels || !o->buffers[1].pixels)
        fail("out of memory");
    check_glow_anchor(o, reference);
    update_clouds(SKY_KEYFRAME_SECONDS - 1e-8);
    restore(o, &o->buffers[0], (struct rect){0, 0, output_width, height});
    update_clouds(SKY_KEYFRAME_SECONDS);
    restore(o, reference, (struct rect){0, 0, output_width, height});
    if (memcmp(o->buffers[0].pixels, reference->pixels, size))
        fail("sky keyframe boundary discontinuity");
    for (int index = 0; index < output_count; index++) {
        o->index = index;
        for (int j = 0; j < 2; j++) {
            o->buffers[j].count = 0;
            o->buffers[j].initialized = false;
            o->buffers[j].film_epoch = -1;
            restore(o, &o->buffers[j], (struct rect){0, 0, output_width, height});
        }
        for (int frame = 0; frame < 2404; frame++) {
            const double jumps[] = {width / 0.25 - 0.5, width / 0.25 + 0.5, 1000000, 0};
            double t = frame < 2400 ? frame / 24.0 : jumps[frame - 2400];
            update_clouds(t);
            update_film(t);
            struct buffer *b = &o->buffers[frame % 2];
            paint(o, b, t);
            restore(o, reference, (struct rect){0, 0, output_width, height});
            reference->count = 0;
            for (int j = 0; j < effect_count; j++) detail(o, reference, &effects[j], t);
            if (memcmp(b->pixels, reference->pixels, size)) fail("sprite restoration regression");
            if (frame) check_damage(o, b, o->buffers[(frame + 1) % 2].pixels);
            remember_frame(o, b);
        }
    }
    printf("Checked %d details on %d outputs at 24 fps across 100 seconds, interpolation, film grain, anchored glow, damage and wraps/time jumps; no trails.\n",
           effect_count, output_count);
    free(reference->pixels);
    free(reference);
    for (int j = 0; j < 2; j++) free(o->buffers[j].pixels);
    free(o);
}

int main(int argc, char **argv) {
    bool check = argc > 1 && !strcmp(argv[1], "--check");
    if (check) { argc--; argv++; }
    if (argc < 3 || argc > MAX_OUTPUTS + 2) {
        fprintf(stderr, "Usage: twilight-wallpaper [--check] SCENE_DIR OUTPUT [OUTPUT ...]\n"
                        "TWILIGHT_FPS=1..30 (default 24); SIGUSR1 toggles pause.\n"
                        "TWILIGHT_GRAIN_STRENGTH=0..2 (default 0.8); TWILIGHT_GRAIN_FPS=1..24 (default 8).\n"
                        "TWILIGHT_TIME_OFFSET=seconds previews a later point without waiting.\n");
        return EXIT_FAILURE;
    }
    output_count = argc - 2;
    output_names = argv + 2;
    load_scene(argv[1]);
    load_clouds(argv[1]);
    load_film(argv[1]);
    if (check) { check_scene(); return 0; }
    const char *fps = getenv("TWILIGHT_FPS");
    if (fps) {
        char *end;
        double n = strtod(fps, &end);
        if (*end || !isfinite(n) || n < 1 || n > 30) fail("TWILIGHT_FPS must be 1..30");
        interval = 1 / n;
    }
    display = wl_display_connect(NULL);
    if (!display) fail("cannot connect to Wayland");
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    if (wl_display_roundtrip(display) < 0) fail("Wayland registry failed");
    if (!compositor || !shm || !shell)
        fail("compositor lacks layer-shell or wl_output v4 support");
    globals_ready = true;
    if (wl_display_roundtrip(display) < 0) fail("Wayland output discovery failed");
    for (int i = 0; i < MAX_OUTPUTS; i++) if (outputs[i].id) start_output(&outputs[i]);
    struct sigaction action = { .sa_handler = signal_handler };
    sigemptyset(&action.sa_mask);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGUSR1, &action, NULL);
    double offset = 0;
    const char *seek = getenv("TWILIGHT_TIME_OFFSET");
    if (seek) {
        char *end;
        offset = strtod(seek, &end);
        if (!*seek || *end || !isfinite(offset) || offset < 0 || offset > 1e9)
            fail("TWILIGHT_TIME_OFFSET must be 0..1e9 seconds");
    }
    double start = now() - offset;
    while (running) {
        if (wl_display_dispatch_pending(display) < 0) break;
        double time = now();
        if (!paused) {
            update_clouds(time - start);
            update_film(time - start);
        }
        for (int i = 0; i < MAX_OUTPUTS; i++) {
            struct output *o = &outputs[i];
            if (!o->configured || o->frame || (paused && o->painted)) continue;
            struct buffer *b = available(o);
            if (b && time >= o->next) {
                submit(o, b, time - start);
                o->next = time + interval;
            }
        }
        while (wl_display_prepare_read(display) != 0)
            if (wl_display_dispatch_pending(display) < 0) goto done;
        int timeout = -1;
        for (int i = 0; i < MAX_OUTPUTS; i++) {
            struct output *o = &outputs[i];
            if (!o->configured || o->frame || (paused && o->painted) || !available(o))
                continue;
            int wait = (int)ceil(fmax(0, o->next - now()) * 1000);
            if (timeout < 0 || wait < timeout) timeout = wait;
        }
        int flushed = wl_display_flush(display);
        if (flushed < 0 && errno != EAGAIN) { wl_display_cancel_read(display); break; }
        struct pollfd pfd = { .fd = wl_display_get_fd(display),
            .events = POLLIN | (flushed < 0 ? POLLOUT : 0) };
        int result = poll(&pfd, 1, timeout);
        if (result > 0 && (pfd.revents & POLLIN)) {
            if (wl_display_read_events(display) < 0) break;
        } else wl_display_cancel_read(display);
        if ((result < 0 && errno != EINTR) ||
            (result > 0 && (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)))) break;
    }
done:
    for (int i = 0; i < MAX_OUTPUTS; i++) if (outputs[i].id) destroy_output(&outputs[i]);
    zwlr_layer_shell_v1_destroy(shell);
    wl_shm_destroy(shm);
    wl_compositor_destroy(compositor);
    wl_registry_destroy(registry);
    wl_display_flush(display);
    wl_display_disconnect(display);
    munmap((void *)base, (size_t)width * height * 4);
    munmap((void *)layer_data, layer_data_size);
    munmap((void *)sky_mask, (size_t)width * cloud_height);
    free(cloud_background);
    free(previous_sky);
    for (int i = 0; i < cloud_count; i++) {
        free(clouds[i].damage_tiles);
        free(clouds[i].spans);
    }
    free(sky_spans);
    if (film_source) munmap((void *)film_source, GRAIN_SIDE * GRAIN_STRIDE);
    free(scaled_film_noise);
    return running ? EXIT_FAILURE : EXIT_SUCCESS;
}
