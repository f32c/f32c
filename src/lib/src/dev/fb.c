/*-
 * Copyright (c) 2013 - 2024 Marko Zec
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

#include <dev/io.h>
#include <dev/fb.h>

typedef void plotfn_t(int x, int y, int mode_color, uint8_t *dp);

/* A fixed-width 6 x 10 bitmapped font, borrowed from X11 */
static uint8_t font_map[] = {
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


uint8_t *fb[2];
uint8_t *fb_active;
uint8_t fb_visible;
uint8_t fb_drawable;
uint8_t fb_mode = 3;

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
#else /* !COMPOSITING2 */
#define	_FB_WIDTH	512
#define	_FB_HEIGHT	288
#endif /* !COMPOSITING2 */

void
fb_set_mode(int mode)
{

	free(fb[1]);
	fb[1] = NULL;
	fb_drawable = 0;
	fb_visible = 0;

	mode &= 3;
	if (mode > 1) {
		free(fb[0]);
		free(fb[1]);
		fb[0] = NULL;
		fb[1] = NULL;
	} else {
		if (fb_mode != mode) {
			free(fb[0]);
			free(fb[1]);
			fb[0] = malloc(_FB_WIDTH * _FB_HEIGHT << mode);
		}
		if (fb[0] == NULL)
			mode = 3;
	}
	fb_mode = mode;
	fb_active = fb[0];
	if (fb_mode <= 1) {
		fb_rectangle(0, 0, _FB_WIDTH - 1, _FB_HEIGHT - 1, 0);
#ifdef COMPOSITING2
		/* compisiting2 will be initialized as simple framebuffer */
		/* Initialize compositing line descriptors */
		for (int i = 0; i < _FB_HEIGHT; i++) {
			scanlines[i].next = NULL;
			scanlines[i].x = 0;
			scanlines[i].n = _FB_WIDTH - 1;
			scanlines[i].bmp = &fb_active[_FB_WIDTH * i << mode];
			sp[i] = &scanlines[i];
		}
#endif
	}

#ifdef __mips__
#ifdef COMPOSITING2
	if (fb_mode <= 1)
	{
		OUTW(IO_C2VIDEO_BASE, sp);
		OUTB(IO_TXTMODE_CTRL, 0b11000000); // enable video, yes bitmap, no text mode, no cursor
	}
	else
		OUTW(IO_C2VIDEO_BASE, NULL);
#else
	OUTW(IO_FB, ((uint32_t) fb_active) | fb_mode);
#endif
#endif
}


void
fb_set_drawable(int visual)
{

	if (visual < 0 || visual > 1)
		return;
	if (fb[visual] == NULL)
		fb[visual] = malloc(_FB_WIDTH * _FB_HEIGHT << fb_mode);
	if (fb[visual] == NULL)
		return;
	fb_drawable = visual;
	fb_active = fb[visual];
}


void
fb_set_visible(int visual)
{

	if (visual < 0 || visual > 1 || fb[visual] == NULL)
		return;
	fb_visible = visual;
#ifdef __mips__
	OUTW(IO_FB, ((uint32_t) fb[fb_visible]) | fb_mode);
#endif
}


#define	FP_ONE (0x80)
#define	FP_HALF (0x40)

#define	NEG_X	0x01
#define	NEG_Y	0x02
#define	SWAP_XY	0x04

static int
atan_i(int y, int x)
{
	int flags = 0;
	int tmp;
	int atan;

	/* fold input values into first 45 degree sector */
	if (y < 0) {
		flags |= NEG_Y;
		y = -y;
	}

	if (x < 0) {
		flags |= NEG_X;
		x = -x;
	}

	if (y > x) {
		flags |= SWAP_XY;
		tmp = x;
		x = y;
		y = tmp;
	}

	/* compute ratio y/x in 0.7 format. */
	if (x == 0)
		return(0);
	if (x == y)
		atan = FP_HALF / 2;
	else
		atan = (y << 5) / x;

	/* unfold result */
	if (flags & SWAP_XY)
		atan = FP_HALF - atan;

	if (flags & NEG_X)
		atan = FP_ONE - atan;

	if (flags & NEG_Y)
		atan = -atan;

	return (atan);
}


#define	WR	77	/* 0.299 * 256 */
#define	WB	29	/* 0.114 * 256 */
#define	WG	150	/* 0.586 * 256 */
#define	WU	126	/* 0.492 * 256 */
#define	WV	224	/* 0.877 * 256 */

int
fb_rgb2pal(uint32_t rgb) {
	int color, luma, chroma, saturation;
	int u, v;
	uint8_t r = rgb >> 16;
	uint8_t g = rgb >> 8;
	uint8_t b = rgb;
	
	/* Transform RGB into YUV */
	luma = (WR * r + WB * b + WG * g) >> 8;
	u = WU * (b - luma);
	v = WV * (r - luma);

	/* Transform {U, V} cartesian into polar {chroma, saturation} coords */
	chroma = ((atan_i(v >> 8, u >> 8) >> 2) - 49) & 0x3f;
	u = ABS(u);
	v = ABS(v);
	if (u > v)
		saturation = u + v * 3 / 8 + (1 << 10);
	else
		saturation = v + u * 3 / 8 + (1 << 10);
	saturation >>= 11;
	if (__predict_false(saturation > 15))
		saturation = 15;

	if (__predict_true(fb_mode)) {
		/* 16-bit encoding */
		if (__predict_true(saturation < 4)) {
			color = luma >> 1;
			if (__predict_true(saturation != 0)) {
				color |= (chroma & 0x3e) << 6;
				color |= saturation << 12;
			}
		} else
			color = (saturation << 12) |
			    (chroma << 6) | (luma >> 2);
	} else {
		/* 8-bit encoding */
		chroma >>= 2;
		if (__predict_false(saturation > 8))
			/* saturated color */
			color = 192 + (luma / 64) * 16 + chroma;
		else if (__predict_false(saturation > 4))
			/* medium color */
			color = 128 + (luma / 64) * 16 + chroma;
		else if (__predict_true(saturation > 0)) {
			/* dim color */
			if (__predict_false(luma < 32))
				color = 16 + chroma;
			else
				color = (luma / 32) * 16 + chroma;
		} else
			/* grayscale */
			color = luma / 16;
	}

	return (color);
}


#ifdef __mips__
__attribute__((optimize("-O3")))
#endif
void
fb_plot(int x, int y, int color)
{
	int off = y * _FB_WIDTH + x;
	uint8_t *dp = fb_active;

	if (__predict_false(y < 0 || y >= _FB_HEIGHT || fb_mode > 1 ||
	    x < 0 || x >= _FB_WIDTH))
		return;

	if (fb_mode == 0)
		dp[off] = color;
	else
		*((uint16_t *) &dp[off << 1]) = color;
}


static void
plot_internal_8(int x, int y, int color, uint8_t *dp)
{

	if (!(y < 0 || y >= _FB_HEIGHT|| x < 0 || x >= _FB_WIDTH))
		dp[y * _FB_WIDTH + x] = color;
}


static void
plot_internal_16(int x, int y, int color, uint8_t *dp)
{
	uint16_t *dp16 = (void *)dp;

	if (!(y < 0 || y >= _FB_HEIGHT || x < 0 || x >= _FB_WIDTH))
		dp16[y * _FB_WIDTH + x] = color;
}


static void
plot_internal_unbounded_8(int x, int y, int color, uint8_t *dp)
{

	dp[y * _FB_WIDTH + x] = color;
}


static void
plot_internal_unbounded_16(int x, int y, int color, uint8_t *dp)
{
	uint16_t *dp16 = (void *)dp;

	dp16[y * _FB_WIDTH + x] = color;
}


void
fb_rectangle(int x0, int y0, int x1, int y1, int color)
{
	int x, i, l;

	if (fb_mode > 1)
		return;

	if (x1 < x0) {
		x = x0;
		x0 = x1;
		x1 = x;
	}
	if (y1 < y0) {
		x = y0;
		y0 = y1;
		y1 = x;
	}
	if (__predict_false(x0 < 0))
		x0 = 0;
	if (__predict_false(y0 < 0))
		y0 = 0;
	if (__predict_false(x1 >= _FB_WIDTH))
		x1 = _FB_WIDTH - 1;
	if (__predict_false(y1 >= _FB_HEIGHT))
		y1 = _FB_HEIGHT - 1;

	if (fb_mode) {
		uint16_t *fb16 = (void *) fb_active;
		color = (color << 16) | (color & 0xffff);
		for (; y0 <= y1; y0++) {
			i = y0 * _FB_WIDTH + x0;
			l = x1 - x0 + 1;
			if (i & 1) {
				fb16[i++] = color;
				l--;
			}
			for (; l >= 10; i += 10, l -= 10) {
				*((int *) &fb16[i + 0]) = color;
				*((int *) &fb16[i + 2]) = color;
				*((int *) &fb16[i + 4]) = color;
				*((int *) &fb16[i + 6]) = color;
				*((int *) &fb16[i + 8]) = color;
			}
			for (; l >= 2; i += 2, l -= 2)
				*((int *) &fb16[i]) = color;
			if (l)
				fb16[i++] = color;
		}
	} else {
		uint8_t *fb8 = (void *) fb_active;
		color = (color << 8) | (color & 0xff);
		color = (color << 16) | (color & 0xffff);
		for (; y0 <= y1; y0++) {
			i = y0 * _FB_WIDTH + x0;
			for (l = x1 - x0 + 1; (i & 3) != 0 && l > 0; l--)
				fb8[i++] = color;
			for (; l >= 20; i += 20, l -= 20) {
				*((int *) &fb8[i + 0]) = color;
				*((int *) &fb8[i + 4]) = color;
				*((int *) &fb8[i + 8]) = color;
				*((int *) &fb8[i + 12]) = color;
				*((int *) &fb8[i + 16]) = color;
			}
			for (; l >= 4; i += 4, l -= 4)
				*((int *) &fb8[i]) = color;
			for (; l > 0; l--)
				fb8[i++] = color;
		}
	}
}


#ifdef __mips__
__attribute__((optimize("-O3")))
#endif
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
 
	if (x0 < 0 || x0 >= _FB_WIDTH || y0 < 0 || y0 >= _FB_HEIGHT ||
	    x1 < 0 || x1 >= _FB_WIDTH || y1 < 0 || y1 >= _FB_HEIGHT) {
		if (fb_mode)
			plotfn = plot_internal_16;
		else
			plotfn = plot_internal_8;
	} else if (fb_mode)
		plotfn = plot_internal_unbounded_16;
	else
		plotfn = plot_internal_unbounded_8;

	if (fb_mode > 1)
		return;

	plotfn(x0, y0, color, fb_active);
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
		plotfn(x0, y0, color, fb_active);
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
 
	if (x0 - r < 0 || x0 + r >= _FB_WIDTH
	    || y0 - r < 0 || y0 + r >= _FB_HEIGHT) {
		if (fb_mode)
			plotfn = plot_internal_16;
		else
			plotfn = plot_internal_8;
	} else if (fb_mode)
		plotfn = plot_internal_unbounded_16;
	else
		plotfn = plot_internal_unbounded_8;

	if (fb_mode > 1)
		return;

	plotfn(x0, y0 + r, color, fb_active);
	plotfn(x0, y0 - r, color, fb_active);
	plotfn(x0 + r, y0, color, fb_active);
	plotfn(x0 - r, y0, color, fb_active);
 
	while(x < y) {
		if (f >= 0) {
			y--;
			ddF_y += 2;
			f += ddF_y;
		}
		x++;
		ddF_x += 2;
		f += ddF_x;    
		plotfn(x0 + x, y0 + y, color, fb_active);
		plotfn(x0 - x, y0 + y, color, fb_active);
		plotfn(x0 + x, y0 - y, color, fb_active);
		plotfn(x0 - x, y0 - y, color, fb_active);
		plotfn(x0 + y, y0 + x, color, fb_active);
		plotfn(x0 - y, y0 + x, color, fb_active);
		plotfn(x0 + y, y0 - x, color, fb_active);
		plotfn(x0 - y, y0 - x, color, fb_active);
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

	curcolor = fb8[y * _FB_WIDTH + x];
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
		for (; y >= 0 && fb8[y * _FB_WIDTH + x] == curcolor; y--) {}
		for (y++; y < _FB_HEIGHT && fb8[y * _FB_WIDTH + x]
		    == curcolor; y++) {
			fb8[y * _FB_WIDTH + x] = color;
			if (!l && x > 0 &&
			    fb8[y * _FB_WIDTH + x - 1] == curcolor) {
				sp->x = x - 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
				l = 1;
			} else if (l && x > 0 &&
			    fb8[y * _FB_WIDTH + x - 1] != curcolor)
				l = 0;
			if (!r && x < _FB_WIDTH - 1 &&
			    fb8[y * _FB_WIDTH + x + 1] == curcolor) {
				sp->x = x + 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
				r = 1;
			} else if (r && x < _FB_WIDTH - 1 &&
			    fb8[y * _FB_WIDTH + x + 1] != curcolor)
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

	curcolor = fb16[y * _FB_WIDTH + x];
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
		for (; y >= 0 && fb16[y * _FB_WIDTH + x] == curcolor; y--) {}
		for (y++; y < _FB_HEIGHT && fb16[y * _FB_WIDTH + x]
		    == curcolor; y++) {
			fb16[y * _FB_WIDTH + x] = color;
			if (!l && x > 0 &&
			    fb16[y * _FB_WIDTH + x - 1] == curcolor) {
				l = 1;
				sp->x = x - 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
			} else if (l && x > 0 &&
			    fb16[y * _FB_WIDTH + x - 1] != curcolor)
				l = 0;
			if (!r && x < _FB_WIDTH - 1 &&
			    fb16[y * _FB_WIDTH + x + 1] == curcolor) {
				r = 1;
				sp->x = x + 1;
				sp->y = y;
				sp++;
				if (sp - sb == ssiz)
					goto abort;
			} else if (r && x < _FB_WIDTH - 1 &&
			    fb16[y * _FB_WIDTH + x + 1] != curcolor)
				r = 0;
		}
	}
abort:
	free(sb);
}


void
fb_fill(int x, int y, int color)
{

	if (__predict_false(fb_mode > 1))
		return;

	if (__predict_false(x < 0 || y < 0 || x >= _FB_WIDTH
	    || y >= _FB_HEIGHT))
		return;

	if (fb_mode)
		fb_fill_16(x, y, color);
	else
		fb_fill_8(x, y, color);
}


#ifdef __mips__
__attribute__((optimize("-O3")))
#endif
void
fb_text(int x0, int y0, const char *cp, int fgcolor, int bgcolor, int scale)
{
	int c, x, y, xs, ys, off, dot;
	uint8_t *bp;
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
		if (__predict_false(y < 0 || y >= _FB_HEIGHT))
			continue;
		c = *bp;
		for (x = x0, xs = 0; x < x0 + 6 * scale_x; x++, xs++) {
			if (__predict_true(xs == scale_x)) {
				c = c << 1;
				xs = 0;
			}
			if (__predict_false(x < 0 || x >= _FB_WIDTH))
				continue;
			off = y * _FB_WIDTH + x;
			if (__predict_false(c & 0x80))
				dot = fgcolor;
			else if (bgcolor < 0)
				continue;
			else
				dot = bgcolor;
			if (fb_mode)
				*((uint16_t *) &fb_active[off << 1]) = dot;
			else
				fb_active[off] = dot;
		}
	}

	x0 += 6 * scale_x;
	goto next_char;
}
