// SPDX-License-Identifier: GPL-2.0 OR MIT
/* On-device byte-order/tail/alignment/overwrite check of the kernel assembly.
 * Build with drm_format_rgb888_neon.S from the patched kernel tree.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

extern void drm_fb_xrgb8888_to_rgb888_neon(void *, const void *, unsigned int);

static void pack(unsigned char *dst, const unsigned char *src, unsigned int n)
{
    unsigned int count = n >= 32 ? n & ~7U : 0;
    if (count)
        drm_fb_xrgb8888_to_rgb888_neon(dst, src, count);
    for (unsigned int i = count; i < n; ++i) {
        dst[i * 3] = src[i * 4];
        dst[i * 3 + 1] = src[i * 4 + 1];
        dst[i * 3 + 2] = src[i * 4 + 2];
    }
}

int main(void)
{
    unsigned char src[1280 * 4 + 64], dst[1280 * 3 + 64];
    unsigned int cases = 0;
    for (unsigned int n = 0; n <= 1280; ++n) {
        for (unsigned int align = 0; align < 8; ++align) {
            for (unsigned int i = 0; i < sizeof(src); ++i)
                src[i] = (i * 37U + n * 13U + (i >> 8)) & 255;
            memset(dst, 0xa5, sizeof(dst));
            unsigned char *d = dst + 16 + align;
            const unsigned char *s = src + 16 + (7 - align);
            pack(d, s, n);
            for (unsigned int i = 0; i < n * 3; ++i)
                if (d[i] != s[(i / 3) * 4 + i % 3]) {
                    fprintf(stderr, "Pixel mismatch n=%u align=%u byte=%u\n", n, align, i);
                    return 1;
                }
            for (unsigned int i = 0; i < sizeof(dst); ++i)
                if ((i < 16 + align || i >= 16 + align + n * 3) && dst[i] != 0xa5) {
                    fprintf(stderr, "Guard overwritten n=%u align=%u byte=%u\n", n, align, i);
                    return 1;
                }
            ++cases;
        }
    }
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (unsigned int i = 0; i < 100000; ++i)
        pack(dst, src, 1280);
    clock_gettime(CLOCK_MONOTONIC, &end);
    double ns = (end.tv_sec - start.tv_sec) * 1e9 + end.tv_nsec - start.tv_nsec;
    printf("PASS: %u widths/alignments; 1280-pixel cached row %.0f ns (userspace only)\n", cases, ns / 100000);
    return 0;
}
