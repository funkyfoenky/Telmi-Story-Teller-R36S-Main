#ifndef SOYSAUCE_FB_H
#define SOYSAUCE_FB_H

#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

/* Blit software vers /dev/fb0 — même chemin que bootScreen (visible sur le panneau).
 * KMSDRM après un splash fb0 crée une fenêtre SDL mais ne scanne plus le LCD. */

static int soy_fb_fd = -2;
static struct fb_fix_screeninfo soy_finfo;
static struct fb_var_screeninfo soy_vinfo;
static char *soy_fbp;

static int soysauce_fb_init(void)
{
	int bfd;

	if (soy_fb_fd >= 0)
		return 0;

	bfd = open("/sys/class/graphics/fb0/blank", O_WRONLY);
	if (bfd >= 0) {
		write(bfd, "0", 1);
		close(bfd);
	}

	soy_fb_fd = open("/dev/fb0", O_RDWR);
	if (soy_fb_fd < 0)
		return -1;
	if (ioctl(soy_fb_fd, FBIOGET_FSCREENINFO, &soy_finfo) ||
	    ioctl(soy_fb_fd, FBIOGET_VSCREENINFO, &soy_vinfo)) {
		close(soy_fb_fd);
		soy_fb_fd = -1;
		return -1;
	}
	soy_fbp = mmap(0, soy_finfo.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED,
		       soy_fb_fd, 0);
	if (soy_fbp == MAP_FAILED) {
		close(soy_fb_fd);
		soy_fb_fd = -1;
		return -1;
	}
	return 0;
}

static uint16_t soysauce_rgb565(uint8_t r, uint8_t g, uint8_t b)
{
	return (uint16_t)(((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3));
}

static uint32_t soysauce_argb32(uint8_t r, uint8_t g, uint8_t b)
{
	/* Identique à bootScreen.c : 0xAARRGGBB */
	return 0xFF000000u | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
}

static void soysauce_fb_fill(uint8_t r, uint8_t g, uint8_t b)
{
	long i, n;

	if (soysauce_fb_init() < 0)
		return;
	if (soy_vinfo.bits_per_pixel == 32) {
		uint32_t c = soysauce_argb32(r, g, b);
		uint32_t *p = (uint32_t *)soy_fbp;
		n = soy_finfo.smem_len / 4;
		for (i = 0; i < n; i++)
			p[i] = c;
	} else if (soy_vinfo.bits_per_pixel == 16) {
		uint16_t c = soysauce_rgb565(r, g, b);
		uint16_t *p = (uint16_t *)soy_fbp;
		n = soy_finfo.smem_len / 2;
		for (i = 0; i < n; i++)
			p[i] = c;
	}
	msync(soy_fbp, soy_finfo.smem_len, MS_SYNC);
}

static void soysauce_fb_present(SDL_Surface *src)
{
	int y, fw, fh, copy_w;
	long line;

	if (src == NULL)
		return;
	if (soysauce_fb_init() < 0)
		return;

	fw = (int)soy_vinfo.xres;
	fh = (int)soy_vinfo.yres;
	line = (long)soy_finfo.line_length;

	SDL_LockSurface(src);
	if (soy_vinfo.bits_per_pixel == 32) {
		copy_w = src->w < fw ? src->w : fw;
		for (y = 0; y < src->h && y < fh; y++) {
			memcpy(soy_fbp + y * line,
			       (uint8_t *)src->pixels + y * src->pitch,
			       (size_t)copy_w * 4);
		}
	} else if (soy_vinfo.bits_per_pixel == 16) {
		int x;
		for (y = 0; y < src->h && y < fh; y++) {
			uint8_t *row = (uint8_t *)src->pixels + y * src->pitch;
			for (x = 0; x < src->w && x < fw; x++) {
				uint8_t r, g, b;
				Uint32 pixel;
				memcpy(&pixel, row + x * 4, 4);
				SDL_GetRGB(pixel, src->format, &r, &g, &b);
				*(uint16_t *)(soy_fbp + y * line + x * 2) =
					soysauce_rgb565(r, g, b);
			}
		}
	}
	SDL_UnlockSurface(src);
}

#endif
