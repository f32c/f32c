/*-
 * Copyright (c) 2013 - 2025 Marko Zec
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

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <dev/io.h>
#include <dev/fb.h>

static const struct modeline fb_modelines[] = {
    { /* 0: 1280x720p @ 60 Hz, 16:9 */
	74250, 1280, 1390, 1430, 1650, 720, 725, 730, 750, 0, 0, 0
    },
    { /* 1: 1280x720p @ 50 Hz, 16:9 */
	74250, 1280, 1720, 1760, 1980, 720, 725, 730, 750, 0, 0, 0
    },
    { /* 2: 1920x1080i @ 60 Hz, 16:9 */
	74250, 1920, 2008, 2052, 2200, 1080, 1084, 1094, 1125, 0, 0, 1
    },
    { /* 3: 1920x1080i @ 50 Hz, 16:9 */
	74250, 1920, 2448, 2492, 2640, 1080, 1084, 1094, 1125, 0, 1, 1
    },
    { /* 4: 1920x1080p @ 30 Hz, 16:9 */
	74250, 1920, 2008, 2052, 2200, 1080, 1084, 1089, 1125, 0, 0, 0
    },
    { /* 5: 1920x1080p @ 25 Hz, 16:9 */
	74250, 1920, 2448, 2492, 2640, 1080, 1084, 1089, 1125, 0, 0, 0
    }
};

uint8_t *fb[2];
uint8_t fb_visible;
uint8_t fb_drawable;
uint16_t fb_hdisp;
uint16_t fb_vdisp;

uint8_t *fb_active;
uint8_t fb_bpp;
static uint8_t fb_bpp_code;

typedef void plotfn_t(int, int, int);
typedef void plotfn_off_t(void *, int, int);
static plotfn_off_t *fb_plotfn_off;

static const uint8_t font_map[];

#define	ABS(a) (((a) < 0) ? -(a) : (a))

//#define COMPOSITING2

#ifdef COMPOSITING2
#define	_FB_WIDTH	640
#define	_FB_HEIGHT	480

/* NOTE from compositing_line.h START */
struct compositing_line {
	struct compositing_line *next;
	int16_t x;
	uint16_t n;
	uint8_t *bmp;
};
/* NOTE from compositing_line.h END */

static struct compositing_line scanlines[_FB_HEIGHT];
static struct compositing_line *sp[_FB_HEIGHT];
#endif /* !COMPOSITING2 */


static void
plot_bpp_1(void *p, int off, int color)
{
	uint32_t *dp32 = p;
	uint32_t shift = off & 0x1f;
	uint32_t mask = 0x1 << shift;

	dp32 = &dp32[off >> 5];
	*dp32 = (*dp32 & ~mask) | ((color & 0x1) << shift);
}


static void
plot_bpp_2(void *p, int off, int color)
{
	uint32_t *dp32 = p;
	uint32_t shift = (off & 0xf) * 2;
	uint32_t mask = 0x3 << shift;

	dp32 = &dp32[off >> 4];
	*dp32 = (*dp32 & ~mask) | ((color & 0x3) << shift);
}


static void
plot_bpp_4(void *p, int off, int color)
{
	uint32_t *dp32 = p;
	uint32_t shift, mask, val;

	dp32 = &dp32[off >> 3];
	shift = (off << 2);
	val = *dp32;
	shift &= 0x1f;
	color &= 0xf;
	mask = 0xf << shift;
	color <<= shift;
	val &= ~mask;

	*dp32 = color | val;
}


static void
plot_bpp_8(void *p, int off, int color)
{
	uint8_t *dp8 = p;

	dp8[off] = color;
}


static void
plot_bpp_16(void *p, int off, int color)
{
	uint16_t *dp16 = p;

	dp16[off] = color;
}


static void
plot_bpp_24(void *p, int off, int color)
{
	uint32_t *dp24 = p;

	dp24[off] = color;
}


void
fb_set_mode(const struct modeline *ml, int flags)
{

#ifndef COMPOSITING2
	int doublepix = (flags & FB_DOUBLEPIX) != 0;
#endif

	/* Special case: modelines 0 to 5 are predefined here */
	if (((int) ml & 0x7) == (int) ml)
		ml = &fb_modelines[(int) ml];

	free(fb[0]);
	free(fb[1]);
	fb[0] = NULL;
	fb[1] = NULL;
	fb_drawable = 0;
	fb_visible = 0;
	fb_bpp = 0;
	fb_bpp_code = (flags & FB_BPP_MASK);

	switch (fb_bpp_code) {
	case FB_BPP_1:
		fb_plotfn_off = plot_bpp_1;
		break;
	case FB_BPP_2:
		fb_plotfn_off = plot_bpp_2;
		break;
	case FB_BPP_4:
		fb_plotfn_off = plot_bpp_4;
		break;
	case FB_BPP_8:
		fb_plotfn_off = plot_bpp_8;
		break;
	case FB_BPP_16:
		fb_plotfn_off = plot_bpp_16;
		break;
	case FB_BPP_24:
		fb_plotfn_off = plot_bpp_24;
		break;
	default:
		/* turn off the video */
#ifdef COMPOSITING2
		OUTW(IO_C2VIDEO_BASE, NULL);
#else
		OUTW(IO_DV_PIXCFG, 0);
#endif
		return;
	}

#ifdef COMPOSITING2
	fb_hdisp = _FB_WIDTH;
	fb_vdisp = _FB_HEIGHT;
#else
	fb_hdisp = ml->hdisp >> doublepix;
	fb_vdisp = ml->vdisp >> doublepix;
#endif
	fb_bpp = 1 << (fb_bpp_code - 1);

	fb[0] = malloc(fb_hdisp * fb_vdisp * fb_bpp / 8);
	memset(fb[0], 0, fb_hdisp * fb_vdisp * fb_bpp / 8);
	fb_active = fb[0];

#ifdef COMPOSITING2
	/* compositing2 will be initialized as simple framebuffer */
	/* Initialize compositing line descriptors */
	for (int i = 0; i < fb_vdisp; i++) {
		scanlines[i].next = NULL;
		scanlines[i].x = 0;
		scanlines[i].n = fb_hdisp - 1;
		if (fb_bpp_code == FB_BPP_8)
			scanlines[i].bmp = &fb_active[fb_hdisp * i];
		else
			scanlines[i].bmp = &fb_active[fb_hdisp * i << 1];
		sp[i] = &scanlines[i];
	}
	OUTW(IO_C2VIDEO_BASE, sp);
	OUTB(IO_TXTMODE_CTRL, 0b11000000); // enable video, yes bitmap, no text mode, no cursor
#else

	/* set modeline */
	OUTH(IO_DV_HDISP, ml->hdisp);
	OUTH(IO_DV_HSYNCSTART, ml->hsyncstart);
	OUTH(IO_DV_HSYNCEND, ml->hsyncend);
	OUTH(IO_DV_HTOTAL, ml->htotal);
	OUTH(IO_DV_VDISP, ml->vdisp);
	OUTH(IO_DV_VSYNCSTART, ml->vsyncstart);
	OUTH(IO_DV_VSYNCEND, ml->vsyncend);
	OUTH(IO_DV_VTOTAL, ml->vtotal | (ml->hsyncn << 13)
	    | (ml->vsyncn << 14) | (ml->interlace << 15));

	OUTW(IO_DV_DMA_BASE, fb_active);
	OUTW(IO_DV_PIXCFG, fb_bpp_code | (doublepix << 4));
#endif
}


void
fb_set_drawable(int visual)
{

	if (visual < 0 || visual > 1)
		return;
	if (fb[visual] == NULL) {
		fb[visual] = malloc(fb_hdisp * fb_vdisp * fb_bpp / 8);
		if (fb[visual] == NULL)
			return;
		memset(fb[visual], 0, fb_hdisp * fb_vdisp * fb_bpp / 8);
	}
	fb_drawable = visual;
	fb_active = fb[visual];
}


void
fb_set_visible(int visual)
{

	if (visual < 0 || visual > 1 || fb[visual] == NULL)
		return;
	fb_visible = visual;
	OUTW(IO_DV_DMA_BASE, fb[fb_visible]);
}


static void
plot_unbounded(int x, int y, int color)
{
	int off = y * fb_hdisp + x;

	fb_plotfn_off(fb_active, off, color);
}


void
fb_plot(int x, int y, int color)
{

	if (__predict_false(y < 0 || y >= fb_vdisp ||
	    x < 0 || x >= fb_hdisp))
		return;

	plot_unbounded(x, y, color);
}


void
fb_rectangle(int x0, int y0, int x1, int y1, int color)
{
	int x, i, l;
	uint32_t shift, stride;

	if (__predict_false(x1 < x0)) {
		x = x0;
		x0 = x1;
		x1 = x;
	}
	if (__predict_false(y1 < y0)) {
		x = y0;
		y0 = y1;
		y1 = x;
	}
	if (__predict_false(x0 < 0))
		x0 = 0;
	if (__predict_false(y0 < 0))
		y0 = 0;
	if (__predict_false(x1 >= fb_hdisp))
		x1 = fb_hdisp - 1;
	if (__predict_false(y1 >= fb_vdisp))
		y1 = fb_vdisp - 1;

	switch (fb_bpp_code) {
	case FB_BPP_8:
		uint8_t *fb8 = (void *) fb_active;
		l = x1 - x0 + 1;
		i = y0 * fb_hdisp + x0;
		for (; y0 <= y1; y0++, i += fb_hdisp)
			memset(&fb8[i], color, l);
		return;
	case FB_BPP_16:
		uint16_t *fb16 = (void *) fb_active;
		color = (color << 16) | (color & 0xffff);
		for (; y0 <= y1; y0++) {
			i = y0 * fb_hdisp + x0;
			l = x1 - x0 + 1;
			if (i & 1) {
				fb16[i++] = color;
				l--;
			}
			for (; l >= 8; i += 8, l -= 8) {
				*((int *) &fb16[i + 0]) = color;
				*((int *) &fb16[i + 2]) = color;
				*((int *) &fb16[i + 4]) = color;
				*((int *) &fb16[i + 6]) = color;
			}
			for (; l >= 2; i += 2, l -= 2)
				*((int *) &fb16[i]) = color;
			if (l)
				fb16[i++] = color;
		}
		return;
	case FB_BPP_24:
		uint32_t *fb32 = (void *) fb_active;
		for (; y0 <= y1; y0++) {
			i = y0 * fb_hdisp + x0;
			l = x1 - x0 + 1;
			for (; l >= 4; i += 4, l -= 4) {
				fb32[i + 0] = color;
				fb32[i + 1] = color;
				fb32[i + 2] = color;
				fb32[i + 3] = color;
			}
			for (; l > 0; i++, l--)
				fb32[i] = color;
		}
		return;
	case FB_BPP_1:
		color = (color << 1) | (color & 0x1);
	case FB_BPP_2:
		color = (color << 2) | (color & 0x3);
	case FB_BPP_4:
		color = (color << 4) | (color & 0xf);
	default:
	}

	if (fb_bpp == 1)
		shift = 3;
	else if (fb_bpp == 2)
		shift = 2;
	else
		shift = 1;
	stride = 1 << shift;

	for (; y0 <= y1; y0++) {
		for (x = x0; x <= x1 && (x & (stride - 1)) != 0; x++)
			plot_unbounded(x, y0, color);
		l = (x1 - x + 1) & ~(stride - 1);
		i = (y0 * fb_hdisp + x) >> shift;
		memset(&fb_active[i], color, l >> shift);
		for (x += l; x <= x1; x++)
			plot_unbounded(x, y0, color);
	}
}


void
fb_line(int x0, int y0, int x1, int y1, int color)
{
	plotfn_t *plotfn;
	int dx = ABS(x1 - x0);
	int sx = x0 < x1 ? 1 : -1;
	int dy = -ABS(y1 - y0);
	int sy = y0 < y1 ? 1 : -1; 
	int err = dx + dy;
	int e2;
 
	if (fb_bpp == 0)
		return;

	if (x0 < 0 || x0 >= fb_hdisp || y0 < 0 || y0 >= fb_vdisp ||
	    x1 < 0 || x1 >= fb_hdisp || y1 < 0 || y1 >= fb_vdisp)
		plotfn = fb_plot;
	else
		plotfn = plot_unbounded;

	plotfn(x0, y0, color);
	for (;;) {
		if (x0 == x1 && y0 == y1)
			break;
		e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			x0 += sx;
		}
		if (e2 <= dx) {
			err += dx;
			y0 += sy;
		}
		plotfn(x0, y0, color);
	}
}


void
fb_circle(int x0, int y0, int r, int color)
{
	int f = 1 - r;
	int ddF_x = 1;
	int ddF_y = -2 * r;
	int x = 0;
	int y = r;
	plotfn_t *plotfn;
 
	if (fb_bpp == 0)
		return;

	if (x0 - r < 0 || x0 + r >= fb_hdisp
	    || y0 - r < 0 || y0 + r >= fb_vdisp)
		plotfn = fb_plot;
	else
		plotfn = plot_unbounded;

	plotfn(x0, y0 + r, color);
	plotfn(x0, y0 - r, color);
	plotfn(x0 + r, y0, color);
	plotfn(x0 - r, y0, color);
 
	while(x < y) {
		if (f >= 0) {
			y--;
			ddF_y += 2;
			f += ddF_y;
		}
		x++;
		ddF_x += 2;
		f += ddF_x;    
		plotfn(x0 + x, y0 + y, color);
		plotfn(x0 - x, y0 + y, color);
		plotfn(x0 + x, y0 - y, color);
		plotfn(x0 - x, y0 - y, color);
		plotfn(x0 + y, y0 + x, color);
		plotfn(x0 - y, y0 + x, color);
		plotfn(x0 + y, y0 - x, color);
		plotfn(x0 - y, y0 - x, color);
	}
}


void
fb_filledcircle(int x0, int y0, int r, int color)
{
	int f = 1 - r;
	int ddF_x = 1;
	int ddF_y = -2 * r;
	int x = 0;
	int y = r;
 
	fb_plot(x0, y0 + r, color);
	fb_plot(x0, y0 - r, color);
	fb_rectangle(x0 - r, y0, x0 + r, y0, color);
 
	while(x < y) {
		if (f >= 0) {
			y--;
			ddF_y += 2;
			f += ddF_y;
		}
		x++;
		ddF_x += 2;
		f += ddF_x;    
		fb_rectangle(x0 - x, y0 + y, x0 + x, y0 + y, color);
		fb_rectangle(x0 - x, y0 - y, x0 + x, y0 - y, color);
		fb_rectangle(x0 - y, y0 + x, x0 + y, y0 + x, color);
		fb_rectangle(x0 - y, y0 - x, x0 + y, y0 - x, color);
	}
}


static void
fb_fill_8(int x, int y, int color)
{
	uint8_t *fb8 = (void *) fb_active;
	int curcolor, ssiz, l, r;
	struct {
		int16_t x, y;
	} *sb, *sp;

	curcolor = fb8[y * fb_hdisp + x];
	if (curcolor == color)
		return;
    
	ssiz = 4096; /* XXX */
	sp = sb = malloc(sizeof(*sp) * ssiz);
	if (sb == NULL)
		return;
	sp->x = x;
	sp->y = y;
    
	for (; sp >= sb; sp--) {    
		x = sp->x;
		y = sp->y;
		l = r = 0;
		for (; y >= 0 && fb8[y * fb_hdisp + x] == curcolor; y--) {}
		for (y++; y < fb_vdisp && fb8[y * fb_hdisp + x]
		    == curcolor; y++) {
			fb8[y * fb_hdisp + x] = color;
			if (!l && x > 0 &&
			    fb8[y * fb_hdisp + x - 1] == curcolor) {
				sp->x = x - 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
				l = 1;
			} else if (l && x > 0 &&
			    fb8[y * fb_hdisp + x - 1] != curcolor)
				l = 0;
			if (!r && x < fb_hdisp - 1 &&
			    fb8[y * fb_hdisp + x + 1] == curcolor) {
				sp->x = x + 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
				r = 1;
			} else if (r && x < fb_hdisp - 1 &&
			    fb8[y * fb_hdisp + x + 1] != curcolor)
				r = 0;
		}
	}
abort:
	free(sb);
}


static void
fb_fill_16(int x, int y, int color)
{
	uint16_t *fb16 = (void *) fb_active;
	int curcolor, ssiz, l, r;
	struct {
		int16_t x, y;
	} *sb, *sp;

	curcolor = fb16[y * fb_hdisp + x];
	if (curcolor == color)
		return;
    
	ssiz = 4096; /* XXX */
	sp = sb = malloc(sizeof(*sp) * ssiz);
	if (sb == NULL)
		return;
	sp->x = x;
	sp->y = y;
    
	for (; sp >= sb; sp--) {    
		x = sp->x;
		y = sp->y;
		l = r = 0;
		for (; y >= 0 && fb16[y * fb_hdisp + x] == curcolor; y--) {}
		for (y++; y < fb_vdisp && fb16[y * fb_hdisp + x]
		    == curcolor; y++) {
			fb16[y * fb_hdisp + x] = color;
			if (!l && x > 0 &&
			    fb16[y * fb_hdisp + x - 1] == curcolor) {
				l = 1;
				sp->x = x - 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
			} else if (l && x > 0 &&
			    fb16[y * fb_hdisp + x - 1] != curcolor)
				l = 0;
			if (!r && x < fb_hdisp - 1 &&
			    fb16[y * fb_hdisp + x + 1] == curcolor) {
				r = 1;
				sp->x = x + 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
			} else if (r && x < fb_hdisp - 1 &&
			    fb16[y * fb_hdisp + x + 1] != curcolor)
				r = 0;
		}
	}
abort:
	free(sb);
}


void
fb_fill(int x, int y, int color)
{

	if (fb_bpp == 0)
		return;

	if (__predict_false(x < 0 || y < 0 || x >= fb_hdisp
	    || y >= fb_vdisp))
		return;

	if (fb_bpp == 16)
		fb_fill_16(x, y, color);
	else
		fb_fill_8(x, y, color);
}


void
fb_text(int x0, int y0, const char *cp, int fgcolor, int bgcolor, int scale)
{
	int c, x, y, xs, ys, dot, off;
	const uint8_t *bp;
	int scale_y = scale & 0xff;
	int scale_x = (scale >> 16) & 0xff;

	if (scale_y == 0)
		scale_y = 1;
	if (scale_x == 0)
		scale_x = scale_y;

next_char:
	c = *cp++;
	if (c == 0)
		return;
	
	if (c < 32 || c > 126)
		bp = font_map;
	else
		bp = &font_map[(c - 32) * 10];

	for (y = y0, ys = 0; y < y0 + 10 * scale_y; y++, ys++) {
		if (__predict_true(ys == scale_y)) {
			bp++;
			ys = 0;
		}
		if (__predict_false(y < 0))
			continue;
		if (__predict_false(y >= fb_vdisp))
			break;
		c = *bp;
		off = y * fb_hdisp;
		for (x = x0, xs = 0; x < x0 + 6 * scale_x; x++, xs++) {
			if (__predict_true(xs == scale_x)) {
				c = c << 1;
				xs = 0;
			}
			if (__predict_false(x < 0))
				continue;
			if (__predict_false(x >= fb_hdisp))
				break;
			dot = bgcolor;
			if (c & 0x80)
				dot = fgcolor;
			else if (bgcolor < 0)
				continue;
			fb_plotfn_off(fb_active, off + x, dot);
		}
	}

	x0 += 6 * scale_x;
	goto next_char;
}


int
fb_rgb2pal(int rgb)
{
	uint32_t r = (rgb >> 16) & 0xff;
	uint32_t g = (rgb >> 8) & 0xff;
	uint32_t b = rgb & 0xff;
	int i = 0;

	switch (fb_bpp) {
	case 32:
		return (rgb);
	case 16:
		/* RGB565 */
		return ((r & 0xf8) << 8 | (g & 0xfc) << 3 | b >> 3);
	case 8:
		/* RGB332 */
		return ((r & 0xe0) | ((g >> 3) & 0x1c) | b >> 6);
	case 4:
		/* RGBI */
		if (r >= 0xc0 || g >= 0xc0 || b >= 0xc0)
			i = 8;
		return (i | ((r >> 5) & 0x4) | ((g >> 6) & 0x2) | b >> 7);
	case 2:
		/* Grayscale */
		i = (r >> 7) + (g >> 7) + (b >> 7);
		if (r >= 0xc0 || g >= 0xc0 || b >= 0xc0)
			i++;
		return (i);
	case 1:
	default:
		/* B/W */
		if (r >= 0xc0 || g >= 0xc0 || b >= 0xc0)
			i = 1;
		return (i);
	}
}


/* A fixed-width 6 x 10 bitmapped font, borrowed from X11 */
static const uint8_t font_map[] = {
	/* space, 32 */
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	/* exclam, 33 */
	0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x20, 0x00, 0x00,
	/* quotedbl, 34 */
	0x00, 0x50, 0x50, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	/* numbersign, 35 */
	0x00, 0x50, 0x50, 0xF8, 0x50, 0xF8, 0x50, 0x50, 0x00, 0x00,
	/* dollar, 36 */
	0x00, 0x20, 0x70, 0xA0, 0x70, 0x28, 0x70, 0x20, 0x00, 0x00,
	/* percent, 37 */
	0x00, 0x48, 0xA8, 0x50, 0x20, 0x50, 0xA8, 0x90, 0x00, 0x00,
	/* ampersand, 38 */
	0x00, 0x40, 0xA0, 0xA0, 0x40, 0xA8, 0x90, 0x68, 0x00, 0x00,
	/* quotesingle, 39 */
	0x00, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	/* parenleft, 40 */
	0x00, 0x10, 0x20, 0x40, 0x40, 0x40, 0x20, 0x10, 0x00, 0x00,
	/* parenright, 41 */
	0x00, 0x40, 0x20, 0x10, 0x10, 0x10, 0x20, 0x40, 0x00, 0x00,
	/* asterisk, 42 */
	0x00, 0x00, 0x88, 0x50, 0xF8, 0x50, 0x88, 0x00, 0x00, 0x00,
	/* plus, 43 */
	0x00, 0x00, 0x20, 0x20, 0xF8, 0x20, 0x20, 0x00, 0x00, 0x00,
	/* comma, 44 */
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x20, 0x40, 0x00,
	/* hyphen, 45 */
	0x00, 0x00, 0x00, 0x00, 0xF8, 0x00, 0x00, 0x00, 0x00, 0x00,
	/* period, 46 */
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x70, 0x20, 0x00,
	/* slash, 47 */
	0x00, 0x08, 0x08, 0x10, 0x20, 0x40, 0x80, 0x80, 0x00, 0x00,
	/* zero, 48 */
	0x00, 0x20, 0x50, 0x88, 0x88, 0x88, 0x50, 0x20, 0x00, 0x00,
	/* one, 49 */
	0x00, 0x20, 0x60, 0xA0, 0x20, 0x20, 0x20, 0xF8, 0x00, 0x00,
	/* two, 50 */
	0x00, 0x70, 0x88, 0x08, 0x30, 0x40, 0x80, 0xF8, 0x00, 0x00,
	/* three, 51 */
	0x00, 0xF8, 0x08, 0x10, 0x30, 0x08, 0x88, 0x70, 0x00, 0x00,
	/* four, 52 */
	0x00, 0x10, 0x30, 0x50, 0x90, 0xF8, 0x10, 0x10, 0x00, 0x00,
	/* five, 53 */
	0x00, 0xF8, 0x80, 0xB0, 0xC8, 0x08, 0x88, 0x70, 0x00, 0x00,
	/* six, 54 */
	0x00, 0x30, 0x40, 0x80, 0xB0, 0xC8, 0x88, 0x70, 0x00, 0x00,
	/* seven, 55 */
	0x00, 0xF8, 0x08, 0x10, 0x10, 0x20, 0x40, 0x40, 0x00, 0x00,
	/* eight, 56 */
	0x00, 0x70, 0x88, 0x88, 0x70, 0x88, 0x88, 0x70, 0x00, 0x00,
	/* nine, 57 */
	0x00, 0x70, 0x88, 0x98, 0x68, 0x08, 0x10, 0x60, 0x00, 0x00,
	/* colon, 58 */
	0x00, 0x00, 0x20, 0x70, 0x20, 0x00, 0x20, 0x70, 0x20, 0x00,
	/* semicolon, 59 */
	0x00, 0x00, 0x20, 0x70, 0x20, 0x00, 0x30, 0x20, 0x40, 0x00,
	/* less, 60 */
	0x00, 0x08, 0x10, 0x20, 0x40, 0x20, 0x10, 0x08, 0x00, 0x00,
	/* equal, 61 */
	0x00, 0x00, 0x00, 0xF8, 0x00, 0xF8, 0x00, 0x00, 0x00, 0x00,
	/* greater, 62 */
	0x00, 0x40, 0x20, 0x10, 0x08, 0x10, 0x20, 0x40, 0x00, 0x00,
	/* question, 63 */
	0x00, 0x70, 0x88, 0x10, 0x20, 0x20, 0x00, 0x20, 0x00, 0x00,
	/* at, 64 */
	0x00, 0x70, 0x88, 0x98, 0xA8, 0xB0, 0x80, 0x70, 0x00, 0x00,
	/* A, 65 */
	0x00, 0x20, 0x50, 0x88, 0x88, 0xF8, 0x88, 0x88, 0x00, 0x00,
	/* B, 66 */
	0x00, 0xF0, 0x48, 0x48, 0x70, 0x48, 0x48, 0xF0, 0x00, 0x00,
	/* C, 67 */
	0x00, 0x70, 0x88, 0x80, 0x80, 0x80, 0x88, 0x70, 0x00, 0x00,
	/* D, 68 */
	0x00, 0xF0, 0x48, 0x48, 0x48, 0x48, 0x48, 0xF0, 0x00, 0x00,
	/* E, 69 */
	0x00, 0xF8, 0x80, 0x80, 0xF0, 0x80, 0x80, 0xF8, 0x00, 0x00,
	/* F, 70 */
	0x00, 0xF8, 0x80, 0x80, 0xF0, 0x80, 0x80, 0x80, 0x00, 0x00,
	/* G, 71 */
	0x00, 0x70, 0x88, 0x80, 0x80, 0x98, 0x88, 0x70, 0x00, 0x00,
	/* H, 72 */
	0x00, 0x88, 0x88, 0x88, 0xF8, 0x88, 0x88, 0x88, 0x00, 0x00,
	/* I, 73 */
	0x00, 0x70, 0x20, 0x20, 0x20, 0x20, 0x20, 0x70, 0x00, 0x00,
	/* J, 74 */
	0x00, 0x38, 0x10, 0x10, 0x10, 0x10, 0x90, 0x60, 0x00, 0x00,
	/* K, 75 */
	0x00, 0x88, 0x90, 0xA0, 0xC0, 0xA0, 0x90, 0x88, 0x00, 0x00,
	/* L, 76 */
	0x00, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0xF8, 0x00, 0x00,
	/* M, 77 */
	0x00, 0x88, 0x88, 0xD8, 0xA8, 0x88, 0x88, 0x88, 0x00, 0x00,
	/* N, 78 */
	0x00, 0x88, 0x88, 0xC8, 0xA8, 0x98, 0x88, 0x88, 0x00, 0x00,
	/* O, 79 */
	0x00, 0x70, 0x88, 0x88, 0x88, 0x88, 0x88, 0x70, 0x00, 0x00,
	/* P, 80 */
	0x00, 0xF0, 0x88, 0x88, 0xF0, 0x80, 0x80, 0x80, 0x00, 0x00,
	/* Q, 81 */
	0x00, 0x70, 0x88, 0x88, 0x88, 0x88, 0xA8, 0x70, 0x08, 0x00,
	/* R, 82 */
	0x00, 0xF0, 0x88, 0x88, 0xF0, 0xA0, 0x90, 0x88, 0x00, 0x00,
	/* S, 83 */
	0x00, 0x70, 0x88, 0x80, 0x70, 0x08, 0x88, 0x70, 0x00, 0x00,
	/* T, 84 */
	0x00, 0xF8, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00,
	/* U, 85 */
	0x00, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x70, 0x00, 0x00,
	/* V, 86 */
	0x00, 0x88, 0x88, 0x88, 0x50, 0x50, 0x50, 0x20, 0x00, 0x00,
	/* W, 87 */
	0x00, 0x88, 0x88, 0x88, 0xA8, 0xA8, 0xD8, 0x88, 0x00, 0x00,
	/* X, 88 */
	0x00, 0x88, 0x88, 0x50, 0x20, 0x50, 0x88, 0x88, 0x00, 0x00,
	/* Y, 89 */
	0x00, 0x88, 0x88, 0x50, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00,
	/* Z, 90 */
	0x00, 0xF8, 0x08, 0x10, 0x20, 0x40, 0x80, 0xF8, 0x00, 0x00,
	/* bracketleft, 91 */
	0x00, 0x70, 0x40, 0x40, 0x40, 0x40, 0x40, 0x70, 0x00, 0x00,
	/* backslash, 92 */
	0x00, 0x80, 0x80, 0x40, 0x20, 0x10, 0x08, 0x08, 0x00, 0x00,
	/* bracketright, 93 */
	0x00, 0x70, 0x10, 0x10, 0x10, 0x10, 0x10, 0x70, 0x00, 0x00,
	/* asciicircum, 94 */
	0x00, 0x20, 0x50, 0x88, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	/* underscore, 95 */
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF8, 0x00,
	/* grave, 96 */
	0x20, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	/* a, 97 */
	0x00, 0x00, 0x00, 0x70, 0x08, 0x78, 0x88, 0x78, 0x00, 0x00,
	/* b, 98 */
	0x00, 0x80, 0x80, 0xB0, 0xC8, 0x88, 0xC8, 0xB0, 0x00, 0x00,
	/* c, 99 */
	0x00, 0x00, 0x00, 0x70, 0x88, 0x80, 0x88, 0x70, 0x00, 0x00,
	/* d, 100 */
	0x00, 0x08, 0x08, 0x68, 0x98, 0x88, 0x98, 0x68, 0x00, 0x00,
	/* e, 101 */
	0x00, 0x00, 0x00, 0x70, 0x88, 0xF8, 0x80, 0x70, 0x00, 0x00,
	/* f, 102 */
	0x00, 0x30, 0x48, 0x40, 0xF0, 0x40, 0x40, 0x40, 0x00, 0x00,
	/* g, 103 */
	0x00, 0x00, 0x00, 0x78, 0x88, 0x88, 0x78, 0x08, 0x88, 0x70,
	/* h, 104 */
	0x00, 0x80, 0x80, 0xB0, 0xC8, 0x88, 0x88, 0x88, 0x00, 0x00,
	/* i, 105 */
	0x00, 0x20, 0x00, 0x60, 0x20, 0x20, 0x20, 0x70, 0x00, 0x00,
	/* j, 106 */
	0x00, 0x08, 0x00, 0x18, 0x08, 0x08, 0x08, 0x48, 0x48, 0x30,
	/* k, 107 */
	0x00, 0x80, 0x80, 0x88, 0x90, 0xE0, 0x90, 0x88, 0x00, 0x00,
	/* l, 108 */
	0x00, 0x60, 0x20, 0x20, 0x20, 0x20, 0x20, 0x70, 0x00, 0x00,
	/* m, 109 */
	0x00, 0x00, 0x00, 0xD0, 0xA8, 0xA8, 0xA8, 0x88, 0x00, 0x00,
	/* n, 110 */
	0x00, 0x00, 0x00, 0xB0, 0xC8, 0x88, 0x88, 0x88, 0x00, 0x00,
	/* o, 111 */
	0x00, 0x00, 0x00, 0x70, 0x88, 0x88, 0x88, 0x70, 0x00, 0x00,
	/* p, 112 */
	0x00, 0x00, 0x00, 0xB0, 0xC8, 0x88, 0xC8, 0xB0, 0x80, 0x80,
	/* q, 113 */
	0x00, 0x00, 0x00, 0x68, 0x98, 0x88, 0x98, 0x68, 0x08, 0x08,
	/* r, 114 */
	0x00, 0x00, 0x00, 0xB0, 0xC8, 0x80, 0x80, 0x80, 0x00, 0x00,
	/* s, 115 */
	0x00, 0x00, 0x00, 0x70, 0x80, 0x70, 0x08, 0xF0, 0x00, 0x00,
	/* t, 116 */
	0x00, 0x40, 0x40, 0xF0, 0x40, 0x40, 0x48, 0x30, 0x00, 0x00,
	/* u, 117 */
	0x00, 0x00, 0x00, 0x88, 0x88, 0x88, 0x98, 0x68, 0x00, 0x00,
	/* v, 118 */
	0x00, 0x00, 0x00, 0x88, 0x88, 0x50, 0x50, 0x20, 0x00, 0x00,
	/* w, 119 */
	0x00, 0x00, 0x00, 0x88, 0x88, 0xA8, 0xA8, 0x50, 0x00, 0x00,
	/* x, 120 */
	0x00, 0x00, 0x00, 0x88, 0x50, 0x20, 0x50, 0x88, 0x00, 0x00,
	/* y, 121 */
	0x00, 0x00, 0x00, 0x88, 0x88, 0x98, 0x68, 0x08, 0x88, 0x70,
	/* z, 122 */
	0x00, 0x00, 0x00, 0xF8, 0x10, 0x20, 0x40, 0xF8, 0x00, 0x00,
	/* braceleft, 123 */
	0x00, 0x18, 0x20, 0x10, 0x60, 0x10, 0x20, 0x18, 0x00, 0x00,
	/* bar, 124 */
	0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00,
	/* braceright, 125 */
	0x00, 0x60, 0x10, 0x20, 0x18, 0x20, 0x10, 0x60, 0x00, 0x00,
	/* asciitilde, 126 */
	0x00, 0x48, 0xA8, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};


