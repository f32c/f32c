/*-
 * Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/queue.h>

#include <dev/io.h>
#include <dev/fb.h>
#include <tjpgd.h>
#include <upng.h>


struct sprite {
	SLIST_ENTRY(sprite)	spr_le;
	char			*spr_data;
	int32_t			spr_trans_color;
	uint16_t		spr_id;
	uint16_t		spr_size_x;
	uint16_t		spr_size_y;
	char			buf[];
};

typedef struct {
	struct sprite	*sp;
	int32_t		fh;
} jdecomp_handle;


static SLIST_HEAD(, sprite) spr_head;


void
spr_flush(void)
{
	struct sprite *sp;

	do {
		sp = SLIST_FIRST(&spr_head);
		if (sp == NULL)
			return;
		SLIST_REMOVE(&spr_head, sp, sprite, spr_le);
		free(sp);
	} while (0);
}


int
spr_free(int id)
{
	struct sprite *sp;

	SLIST_FOREACH(sp, &spr_head, spr_le)
		if (sp->spr_id == id) {
			SLIST_REMOVE(&spr_head, sp, sprite, spr_le);
			free(sp);
			return (0);
		}
	return (-1);
}


struct sprite *
spr_alloc(int id, int bufsize)
{
	struct sprite *sp;

	spr_free(id);
	sp = malloc(sizeof(struct sprite) + bufsize);
	if (sp == NULL)
		return (sp);
	SLIST_INSERT_HEAD(&spr_head, sp, spr_le);
	sp->spr_data = (void *) &sp->buf;
	sp->spr_id = id;
	sp->spr_trans_color = -1;
	return (sp);
}


int
spr_grab(int id, int x0, int y0, int x1, int y1)
{
	int x, y;
	struct sprite *sp;
	uint16_t *u16src, *u16dst;
	uint8_t *u8src, *u8dst;

	if (x0 < 0 || x1 >= fb_hdisp || x0 > x1 ||
	    y0 < 0 || y1 >= fb_vdisp || y0 > y1 || id < 0 || fb_bpp == 0)
		return (-1);

	sp = spr_alloc(id, (x1 - x0 + 1) * (y1 - y0 + 1) * fb_bpp / 8);
	sp->spr_size_x = x1 - x0 + 1;
	sp->spr_size_y = y1 - y0 + 1;

	if (fb_bpp == 8)
		for (u8dst = (void *) sp->spr_data, y = y0; y <= y1; y++) {
			u8src = (uint8_t *) fb_active;
			u8src += y * fb_hdisp + x0;
			for (x = x0; x <= x1; x++)
				*u8dst++ = *u8src++;
		}
	else
		for (u16dst = (void *) sp->spr_data, y = y0; y <= y1; y++) {
			u16src = (uint16_t *) fb_active;
			u16src += y *fb_hdisp + x0;
			for (x = x0; x <= x1; x++)
				*u16dst++ = *u16src++;
		}
	return (0);
}


int
spr_trans(int id, int color)
{
	struct sprite *sp;

	SLIST_FOREACH(sp, &spr_head, spr_le)
		if (sp->spr_id == id)
			break;
	if (sp == NULL)
		return (-1);
	sp->spr_trans_color = color;
	return (0);
}


int
spr_size(int id, int *w, int *h)
{
	struct sprite *sp;

	SLIST_FOREACH(sp, &spr_head, spr_le)
		if (sp->spr_id == id)
			break;
	if (sp == NULL)
		return (-1);
	*w = sp->spr_size_x;
	*h = sp->spr_size_y;
	return (0);
}


int
spr_put(int id, int x0, int y0)
{
	int x0_v, y0_v, x1, y1, x, y, c;
	struct sprite *sp;
	uint16_t *u16src, *u16dst;
	uint8_t *u8src, *u8dst;

	SLIST_FOREACH(sp, &spr_head, spr_le)
		if (sp->spr_id == id)
			break;
	if (sp == NULL)
		return (-1);

	x1 = x0 + sp->spr_size_x;
	y1 = y0 + sp->spr_size_y;
	x0_v = x0;
	if (x0 < 0)
		x0_v = 0;
	y0_v = y0;
	if (y0 < 0)
		y0_v = 0;
	if (x1 > fb_hdisp)
		x1 = fb_hdisp;
	if (y1 > fb_vdisp)
		y1 = fb_vdisp;

	if (fb_bpp == 8)
		for (y = y0_v; y < y1; y++) {
			u8src = &((uint8_t *) sp->spr_data)[(y - y0)
			    * sp->spr_size_x];
			u8src += (x0_v - x0);
			u8dst = (uint8_t *) fb_active;
			u8dst += y * fb_hdisp + x0_v;
			for (x = x0_v; x < x1; x++) {
				c = *u8src++;
				if (c != sp->spr_trans_color)
					*u8dst = c;
				u8dst++;
			}
		}
	else
		for (y = y0_v; y < y1; y++) {
			u16src = &((uint16_t *) sp->spr_data)[(y - y0)
			    * sp->spr_size_x];
			u16src += (x0_v - x0);
			u16dst = (uint16_t *) fb_active;
			u16dst += y * fb_hdisp + x0_v;
			for (x = x0_v; x < x1; x++) {
				c = *u16src++;
				if (c != sp->spr_trans_color)
					*u16dst = c;
				u16dst++;
			}
		}
	return (0);
}


/* Input function for JPEG decompression */
static uint32_t
jpeg_fetch_encoded(JDEC* jd, BYTE* buff, UINT nbyte)
{
	jdecomp_handle *jh = (jdecomp_handle *)jd->device;
	uint32_t retval;

	if (buff) {
		/* Read bytes from input stream */
		retval = read(jh->fh, buff, nbyte);
	} else {
		/* Remove bytes from input stream */
		retval = lseek(jh->fh, nbyte, SEEK_CUR) ? nbyte : 0;
	}

	return (retval);
}


/* Output funciton for JPEG decompression */
static UINT
jpeg_dump_decoded(JDEC* jd, void* bitmap, JRECT* rect)
{
	jdecomp_handle *jh = (jdecomp_handle *)jd->device;
	struct sprite *sp = jh->sp;
	uint32_t x, y, xlim, ylim;
#if JD_FORMAT < JD_FMT_RGB32
	uint8_t *src;
#else
	uint32_t *src;
#endif
	uint32_t rgb, prev_rgb = 0, color = 0;
	uint16_t *dst16;
	uint8_t *dst8;

	src = (void *)bitmap;
	ylim = rect->bottom;
	if (rect->bottom > sp->spr_size_y - 1)
		ylim = sp->spr_size_y - 1;
	xlim = rect->right;
	if (rect->right > sp->spr_size_x - 1)
		xlim = sp->spr_size_x - 1;
	if (fb_bpp == 16)
		for (y = rect->top; y <= ylim; y++) {
			dst16 = (void *) sp->spr_data;
			dst16 = &dst16[y * sp->spr_size_x + rect->left];
			for (x = rect->left; x <= xlim; x++) {
#if JD_FORMAT < JD_FMT_RGB32
				rgb = src[0] * 65536 + src[1] * 256 + src[2];
				src += 3;
#else
				rgb = *src++;
#endif
				if (rgb != prev_rgb) {
					prev_rgb = rgb;
					color =
					    ((rgb >> 8) & 0xf8) |
					    (rgb & 0xfc00) >> 5 |
					    (rgb & 0xff) >> 3;
				}
				*dst16++ = color;
			}
			if (x < rect->right)
#if JD_FORMAT < JD_FMT_RGB32
				src += 3 * (rect->right - x);
#else
				src += (rect->right - x);
#endif
		}
	else
		for (y = rect->top; y <= ylim; y++) {
			dst8 = (void *) sp->spr_data;
			dst8 = &dst8[y * sp->spr_size_x + rect->left];
			for (x = rect->left; x <= xlim; x++) {
#if JD_FORMAT < JD_FMT_RGB32
				rgb = src[0] * 65536 + src[1] * 256 + src[2];
				src += 3;
#else
				rgb = *src++;
#endif
				if (rgb != prev_rgb) {
					prev_rgb = rgb;
					color =
					    ((rgb >> 16) & 0xe) |
					    (rgb & 0xe000) >> 11 |
					    (rgb & 0xc0) >> 6;
				}
				*dst8++ = color;
			}
			if (x < rect->right)
#if JD_FORMAT < JD_FMT_RGB32
				src += 3 * (rect->right - x);
#else
				src += (rect->right - x);
#endif
		}
	return (1);    /* Continue to decompress */
}


int
spr_load(int id, char *name, int descale)
{
	char work_buf[8192];
	JDEC jdec;
	JRESULT jr;
	jdecomp_handle jh;
	struct sprite *sp;
	upng_t *up;
	uint8_t *rgbsrc;
	uint16_t *u16dst;
	uint8_t *u8dst;
	int i, sx, sy, r, g, b;

	if (fb_bpp == 0)
		return (-1);

	/* Attempt JPEG decoding first */
	jh.fh = open(name, O_RDONLY);
	if (jh.fh < 0)
		return (-1);
	jr = jd_prepare(&jdec, jpeg_fetch_encoded, work_buf,
	    sizeof(work_buf), &jh);
	if (jr == JDR_OK) {
		sp = spr_alloc(id,
		   jdec.width * jdec.height * fb_bpp / 8 >> (descale * 2));
		if (sp == NULL) {
			close(jh.fh);
			return (ENOMEM);
		}
		sp->spr_size_x = jdec.width >> descale;
		sp->spr_size_y = jdec.height >> descale;
		jh.sp = sp;
		r = jd_decomp(&jdec, jpeg_dump_decoded, descale);
		close(jh.fh);
		if (r != JDR_OK) {
			spr_free(id);
			printf("Failed to decompress: rc=%d\n", r);
			return (-1);
		} else
			return (0);
	}
	close(jh.fh);

	/* Not a JPG image, perhaps it's a PNG? */
	up = upng_new_from_file(name);
	if (upng_decode(up) != UPNG_EOK || upng_get_format(up) != 3) {
		upng_free(up);
		return(-1);
	}
	sx = upng_get_height(up);
	sy = upng_get_width(up);
	sp = spr_alloc(id, (sx * sy) * fb_bpp / 8);
	sp->spr_size_x = sx;
	sp->spr_size_y = sy;
	if (sp == NULL) {
		upng_free(up);
		return (ENOMEM);
	}
	if (fb_bpp == 8) {
		u8dst = (void *) sp->spr_data;
		rgbsrc = (void *) upng_get_buffer(up);
		for (i = upng_get_size(up) / 4; i > 0; i--) {
			r = *rgbsrc++;
			g = *rgbsrc++;
			b = *rgbsrc++;
			rgbsrc++;
			/* RGB332 */
			*u8dst++ = (r & 0xe0) | (g & 0xe0) >> 3 | (b & 0x3);
		}
	} else {
		u16dst = (void *) sp->spr_data;
		rgbsrc = (void *) upng_get_buffer(up);
		for (i = upng_get_size(up) / 4; i > 0; i--) {
			r = *rgbsrc++;
			g = *rgbsrc++;
			b = *rgbsrc++;
			rgbsrc++;
			/* RGB565 */
			*u16dst++ =
			    (r & 0xf8) << 8 | (g & 0xfc) << 3 | (b & 0x1f);
		}
	}
	upng_free(up);
	return (0);
}


int
jpg_load(char *name, int descale)
{
	char work_buf[8192];
	JDEC jdec;
	JRESULT r;
	jdecomp_handle jh;
	struct sprite spr;

	if (fb_bpp == 0)
		return (-1);
	jh.fh = open(name, O_RDONLY);
	if (jh.fh < 0)
		return (-1);
	r = jd_prepare(&jdec, jpeg_fetch_encoded, work_buf,
	    sizeof(work_buf), &jh);
	if (r == JDR_OK) {
		jh.sp = &spr;
		spr.spr_data = (void *) fb_active;
		spr.spr_size_x = 512;
		spr.spr_size_y = 288;
		r = jd_decomp(&jdec, jpeg_dump_decoded, descale);
		if (r != JDR_OK)
			printf("Failed to decompress: rc=%d\n", r);
	} else {
		printf("Failed to prepare: rc=%d\n", r);
	}
	close(jh.fh);
	return (0);
}
