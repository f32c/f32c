/*-
 * Copyright (c) 2013, 2014 Marko Zec
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
 *
 * $Id$
 */

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <sys/queue.h>

#include "bas.h"

#ifdef f32c
#include <fb.h>
#include <tjpgd.h>
#else
#include "../include/fb.h"
#include "tjpgd.h"
#include <math.h>
#include <sys/time.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#endif


/* User defined device identifier for JPEG decompression*/
typedef struct {
	int fh;		/* File handle */
	BYTE *fbuf;	/* Pointer to the frame buffer for output function */
	UINT wfbuf;	/* Width of the frame buffer [pix] */
} IODEV;


static const struct colormap {
	int value;
	char *name;
} colormap[] = {
	{ 0x000000, "black" },
	{ 0x000080, "navy" },
	{ 0x0000ff, "blue" },
	{ 0x008000, "green" },
	{ 0x008080, "teal" },
	{ 0x00ff00, "lime" },
	{ 0x00ffff, "cyan" },
	{ 0x404040, "gray25" },
	{ 0x4b0082, "indigo" },
	{ 0x800000, "maroon" },
	{ 0x800080, "purple" },
	{ 0x808000, "olive" },
	{ 0x808080, "gray" },
	{ 0x808080, "gray50" },
	{ 0x842222, "brown" },	/* a52a2a maps to red with 8-bit PAL pallete */
	{ 0xc0c0c0, "gray75" },
	{ 0xee82ee, "violet" },
	{ 0xf0e68c, "khaki" },
	{ 0xff0000, "red" },
	{ 0xff00ff, "magenta" },
	{ 0xffa500, "orange" },
	{ 0xffc0cb, "pink" },
	{ 0xffff00, "yellow" },
	{ 0xffffff, "white" },
	{ -1, NULL },
};

void *fb_buff[2];
static int bgcolor;
static int last_x;
static int last_y;
static uint16_t fgcolor;
static uint16_t fb_mode = 3;
static uint8_t fb_visible;
static uint8_t fb_drawable;

#ifndef f32c
static Display *dis;
static Window win;
static XImage *ximg;
static uint32_t *img;
static int x11_scale = 1;
static int x11_onroot;
static int x11_update_pending;
static struct timeval x11_last_updated;
static struct timezone tz;
static uint32_t map8[256];
static uint32_t map16[65536];
#endif

#ifdef f32c
#define	X11_SCHED_UPDATE()
#else
#define	X11_SCHED_UPDATE() do {					\
	if (fb_visible == fb_drawable)				\
		x11_update_pending = 1;				\
	} while (0)
#endif


struct sprite {
	SLIST_ENTRY(sprite)	spr_le;
	int			spr_trans_color;
	uint16_t		spr_id;
	uint16_t		size_x;
	uint16_t		size_y;
	char			data[];
};

static SLIST_HEAD(, sprite) spr_head;


static void
spr_flush(void)
{
	struct sprite *sp;

	do {
		sp = SLIST_FIRST(&spr_head);
		if (sp == NULL)
			return;
		SLIST_REMOVE(&spr_head, sp, sprite, spr_le);
		mfree(sp);
	} while (0);
}


static int
spr_free(int id)
{
	struct sprite *sp;

	SLIST_FOREACH(sp, &spr_head, spr_le)
		if (sp->spr_id == id) {
			SLIST_REMOVE(&spr_head, sp, sprite, spr_le);
			mfree(sp);
			return (0);
		}
	return (1);
}


static struct sprite *
spr_alloc(int id, int bufsize)
{
	struct sprite *sp;

	spr_free(id);
	sp = mmalloc(sizeof(struct sprite) + bufsize);
	SLIST_INSERT_HEAD(&spr_head, sp, spr_le);
	sp->spr_id = id;
	sp->spr_trans_color = -1;
	
	return (sp);
}


#ifndef f32c
static uint32_t
pal2rgb(int sat, int chroma, int luma)
{
	int u, v, r, g, b;
	float phase, PI = 3.14159265359, ampl = 8;

	phase = PI * (chroma - 13) / 32.0;
	u = 128.0 + ampl * sat * cos(phase);
	v = 128.0 + ampl * sat * sin(phase);
	r = luma * 2 + 1.4075 * (v - 128);
	g = luma * 2 - 0.3455 * (u - 128) - (0.7169 * (v - 128));
	b = luma * 2 + 1.7790 * (u - 128);
	if (r < 0)
		r = 0;
	if (r > 255)
		r = 255;
	if (g < 0)	
		g = 0;
	if (g > 255)	
		g = 255;
	if (b < 0)
		b = 0;
	if (b > 255)
		b = 255;

	return ((r << 16) + (g << 8) + b);
}
#endif


void
setup_fb(void)
{
#ifndef f32c
	int sat, chroma, luma, i;

	/* Populate 16-bit pallete to RGB map */
	for (sat = 0; sat < 4; sat++)
	    for (chroma = 0; chroma < 64; chroma += 2)
		for (luma = 0; luma < 128; luma++) {
		    i = (sat << 12) | ((chroma << 6) | luma);
		    map16[i] = pal2rgb(sat, chroma, luma);
		}
	for (sat = 4; sat < 16; sat++)
	    for (chroma = 0; chroma < 64; chroma++)
		for (luma = 0; luma < 64; luma++) {
		    i = (sat << 12) | ((chroma << 6) | luma);
		    map16[i] = pal2rgb(sat, chroma, luma * 2);
		}
	/* Populate 8-bit pallete to RGB map */
	for (i = 0; i < 16; i++)
		map8[i] = pal2rgb(0, 0, i * 8);
	for (i = 16; i < 128; i++) {
		luma = i / 16 * 4 * 4;
		sat = 2;
		chroma = (i % 16) * 4 + 2;
		map8[i] = pal2rgb(sat, chroma, luma);
	}
	for (i = 128; i < 192; i++) {
		luma = (i - 128) / 16 * 8 * 4 + 16;
		sat = 5;
		chroma = (i % 16) * 4 + 2;
		map8[i] = pal2rgb(sat, chroma, luma);
	}
	for (i = 192; i < 256; i++) {
		luma = (i - 192) / 16 * 8 * 4 + 16;
		sat = 15;
		chroma = (i % 16) * 4 + 2;
		map8[i] = pal2rgb(sat, chroma, luma);
	}
#endif

	/* Turn off video framebuffer */
	fb_set_mode(3, NULL, NULL);
}


#ifndef f32c
void
update_x11(int nowait)
{
	XEvent ev;
	struct timeval now;
	uint8_t *fb_8 = fb_buff[fb_visible];
	uint16_t *fb_16 = fb_buff[fb_visible];
	uint32_t *dstp = img;
	int64_t delta;
	int x, y, xs, ys;

	if (fb_mode > 1)
		return;
	while (XCheckMaskEvent(dis, ExposureMask | StructureNotifyMask, &ev))
		x11_update_pending = 1;
	if (x11_update_pending == 0)
		return;
	gettimeofday(&now, &tz);
	delta = (now.tv_sec - x11_last_updated.tv_sec) * 1000000 +
	    now.tv_usec - x11_last_updated.tv_usec;
	if (!nowait && delta < 30000)
		return;
	x11_update_pending = 0;

	if (fb_mode == 0)
	    for (y = 0; y < 288; y++, fb_8 += 512)
		for (ys = 0; ys < x11_scale; ys++)
		    for (x = 0; x < 512; x++)
			for (xs = 0; xs < x11_scale; xs++)
			    *dstp++ = map8[fb_8[x]];
	else
	    for (y = 0; y < 288; y++, fb_16 += 512)
		for (ys = 0; ys < x11_scale; ys++)
		    for (x = 0; x < 512; x++)
			for (xs = 0; xs < x11_scale; xs++)
			    *dstp++ = map16[fb_16[x]];
	XPutImage(dis, win, DefaultGC(dis, 0), ximg, 0, 0, 0, 0,
	    512 * x11_scale, 288 * x11_scale);
	XFlush(dis);
	gettimeofday(&x11_last_updated, &tz);
}
#endif


int
vidmode(void)
{
	int mode, c;

	mode = evalint();
	if (mode < 0 || mode > 3)
		error(33);	/* argument error */

	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',')
			error(15);
		c = evalint();
		if (c < 1 || c > 4)
			error(33);	/* argument error */
#ifndef f32c
		x11_scale = c;
#endif
		c = getch();
		if (istermin(c))
			point--;
		else {
			if (c != ',')
				error(15);
			c = evalint();
			if (c < 0 || c > 1)
				error(33);	/* argument error */
#ifndef f32c
			x11_onroot = c;
#endif
		}
	}
	check();

	if (mode != fb_mode) {
		mfree(fb_buff[0]);
		if (fb_buff[1])
			mfree(fb_buff[1]);
		fb_buff[0] = NULL;
		fb_buff[1] = NULL;
		if (mode < 2)
			fb_buff[0] = mmalloc(512 * 288 * (mode + 1));
	}
	spr_flush();
	fb_drawable = 0;
	fb_visible = 0;
	fb_set_mode(mode, fb_buff[0], fb_buff[0]);
	fgcolor = fb_rgb2pal(0xffffff);
	bgcolor = fb_rgb2pal(0);
	if (mode < 2)
		fb_rectangle(0, 0, 511, 287, bgcolor);
	last_x = 0;
	last_y = 0;
#ifndef f32c
	if (dis != NULL) {
		XDestroyImage(ximg);
		XUnmapWindow(dis, win);
		XDestroyWindow(dis, win);
		XCloseDisplay(dis);
		dis = NULL;
		img = NULL;
	}
	if (mode < 2) {
		dis = XOpenDisplay(NULL);
		if (dis == NULL)
			error(14);	/* cannot creat file */
		img = malloc(512 * 288 * 4 * x11_scale * x11_scale);
		if (x11_onroot)
			win = RootWindow(dis, 0);
		else {
			win = XCreateSimpleWindow(dis, RootWindow(dis, 0),
			    1, 1, 512 * x11_scale, 288 * x11_scale,
			    10, WhitePixel(dis, 0), BlackPixel(dis, 0));
			XMapWindow(dis, win);
			XStoreName(dis, win, "Rabbit BASIC");
		}
		XSelectInput(dis, win, ExposureMask | StructureNotifyMask);
		XSizeHints* win_size_hints = XAllocSizeHints();
		win_size_hints->flags = PMinSize | PMaxSize;
		win_size_hints->min_width = 512 * x11_scale;
		win_size_hints->min_height = 288 * x11_scale;
		win_size_hints->max_width = 512 * x11_scale;
		win_size_hints->max_height = 288 * x11_scale;
		XSetWMNormalHints(dis, win, win_size_hints);
		XFree(win_size_hints);
		ximg = XCreateImage(dis, DefaultVisual(dis, 0),
		    24, ZPixmap, 0, (void *) img,
		    512 * x11_scale, 288 * x11_scale, 32, 0);
		gettimeofday(&x11_last_updated, &tz);
		XFlush(dis);
	}
#endif
	fb_mode = mode;
	normret;
}


int
drawable(void)
{
	int visual;

	visual = evalint();
	check();
	if (visual < 0 || visual > 1)
		error(36);	/* argument error */
	if (fb_mode > 1)
		error(26);	/* out of data */
	if (fb_buff[visual] == NULL)
		fb_buff[visual] = mmalloc(512 * 288 * (fb_mode + 1));
	fb_drawable = visual;
	fb_set_mode(fb_mode, fb_buff[fb_drawable], fb_buff[fb_visible]);
	normret;
}


int
visible(void)
{
	int visual;

	visual = evalint();
	check();
	if (visual < 0 || visual > 1)
		error(36);	/* argument error */
	if (fb_buff[visual] == NULL || fb_mode > 1)
		error(26);	/* out of data */
	fb_visible = visual;
	fb_set_mode(fb_mode, fb_buff[fb_drawable], fb_buff[fb_visible]);
	X11_SCHED_UPDATE();
	normret;
}


static int
parse_color(void)
{
	char buf[16];
	STR st;
	int c, color = 0;
	uint32_t i, len;

	/* Skip whitespace */
	c = getch();
	point--;

	/* First arg string or numeric? */
	if (checktype()) {
		st = stringeval();
		NULL_TERMINATE(st);
		len = strlen(st->strval);
		if (len == 0 || len > 15) {
			FREE_STR(st);
			error(33);	/* argument error */
		}
		for (i = 0; i <= len; i++)
			buf[i] = tolower(st->strval[i]);
		FREE_STR(st);
		if (buf[0] == '#') {
			if (len != 7)
				error(33);	/* argument error */
			for (i = 1; i < 7; i++) {
				c = buf[i];
				if (!isxdigit(c))
					error(33);	/* argument error */
				if (c <= '9')
					color = (color << 4) + c - '0';
				else
					color = (color << 4) + c - 'a' + 10;
			}
		} else {
			i = -1;
			do {
				if (colormap[++i].name == NULL)
					error(33);	/* argument error */
			} while (strcmp(buf, colormap[i].name) != 0);
			color = colormap[i].value;
		}
		color = fb_rgb2pal(color);
	} else
		color = evalint();
	return (color);
}


int
ink(void)
{
	int color;

	color = parse_color();
	check();
	fgcolor = color & 0xffff;
	normret;
}


int
paper(void)
{
	int color;

	color = parse_color();
	check();
	bgcolor = color;
	normret;
}


int
plot(void)
{
	int x, y, c;
	int firstdot = 1;

	do {
		x = evalint();
		if(getch() != ',')
			error(SYNTAX);
		y = evalint();
		if (firstdot) {
			fb_plot(x, y, fgcolor);
			firstdot = 0;
		} else
			fb_line(last_x, last_y, x, y, fgcolor);
		X11_SCHED_UPDATE();
		last_x = x;
		last_y = y;
		c = getch();
		if (istermin(c)) {
			point--;
			normret;
		}
		if (c != ',')
			error(15);
	} while (1);
}


int
lineto(void)
{
	int x, y, c;

	do {
		x = evalint();
		if(getch() != ',')
			error(SYNTAX);
		y = evalint();
		fb_line(last_x, last_y, x, y, fgcolor);
		X11_SCHED_UPDATE();
		last_x = x;
		last_y = y;
		c = getch();
		if (istermin(c)) {
			point--;
			normret;
		}
		if (c != ',')
			error(15);
	} while (1);
}


int
rectangle(void)
{
	int x0, y0, x1, y1;
	int c, fill = 0;

	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	x1 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y1 = evalint();

	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',')
			error(15);
		fill = evalint();
		check();
		if (fill < 0 || fill > 1)
			error(33);	/* argument error */
	}

	if (fill)
		fb_rectangle(x0, y0, x1, y1, fgcolor);
	else {
		fb_line(x0, y0, x1, y0, fgcolor);
		fb_line(x1, y0, x1, y1, fgcolor);
		fb_line(x1, y1, x0, y1, fgcolor);
		fb_line(x0, y1, x0, y0, fgcolor);
	}
	X11_SCHED_UPDATE();
	normret;
}


int
circle(void)
{
	int x, y, r;
	int c, fill = 0;

	x = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y = evalint();
	if(getch() != ',')
		error(SYNTAX);
	r = evalint();

	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',')
			error(15);
		fill = evalint();
		check();
		if (fill < 0 || fill > 1)
			error(33);	/* argument error */
	}

	if (fill)
		fb_filledcircle(x, y, r, fgcolor);
	else
		fb_circle(x, y, r, fgcolor);
	X11_SCHED_UPDATE();
	normret;
}


int
text(void)
{
	int x, y, c;
	int scale_x = 1;
	int scale_y = 1;
	STR st;

	x = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y = evalint();
	if(getch() != ',')
		error(SYNTAX);
	st = stringeval();
	NULL_TERMINATE(st);
	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',') {
			FREE_STR(st);
			error(15);
		}
		scale_x = evalint() & 0xff;
	}
	c = getch();
	if (istermin(c))
		point--;
	else {
		if (c != ',') {
			FREE_STR(st);
			error(15);
		}
		scale_y = evalint() & 0xff;
	}

	fb_text(x, y, st->strval, fgcolor, bgcolor, (scale_x << 16) | scale_y);
	FREE_STR(st);
	X11_SCHED_UPDATE();
	normret;
}


int
sprgrab(void)
{
	int id, x0, y0, x1, y1, x, y;
	struct sprite *sp;
	uint16_t *u16src, *u16dst;
	uint8_t *u8src, *u8dst;

	id = evalint();
	if(getch() != ',')
		error(SYNTAX);
	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	x1 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y1 = evalint();
	check();

	if (x0 < 0 || x1 > 511 || x0 > x1 ||
	    y0 < 0 || y1 > 287 || y0 > y1 || id < 0 || fb_mode > 1)
		error(15);

	sp = spr_alloc(id, (x1 - x0 + 1) * (y1 - y0 + 1) * (fb_mode + 1));
	sp->size_x = x1 - x0 + 1;
	sp->size_y = y1 - y0 + 1;

	if (fb_mode == 0)
		for (u8dst = (void *) &sp->data, y = y0; y <= y1; y++) {
			u8src = (uint8_t *) fb_buff[fb_drawable];
			u8src += (y << 9) + x0;
			for (x = x0; x <= x1; x++)
				*u8dst++ = *u8src++;
		}
	else
		for (u16dst = (void *) &sp->data, y = y0; y <= y1; y++) {
			u16src = (uint16_t *) fb_buff[fb_drawable];					u16src += (y << 9) + x0;
			for (x = x0; x <= x1; x++)
				*u16dst++ = *u16src++;
		}
	normret;
}


int
sprload(void)
{

	normret;
}


int
sprtrans(void)
{
	int id, color;
	struct sprite *sp;

	id = evalint();
	if(getch() != ',')
		error(SYNTAX);
	color = parse_color();
	check();

	SLIST_FOREACH(sp, &spr_head, spr_le)
		if (sp->spr_id == id)
			break;
	if (sp == NULL)
		error(BADDATA);
	sp->spr_trans_color = color;
	normret;
}


int
sprfree(void)
{
	int c, id;

	/* Skip whitespace */
	c = getch();
	point--;

	if (istermin(c))
		spr_flush();
	else {
		id = evalint();
		check();
		if (spr_free(id))
			error(BADDATA);
	}
	normret;
}


int
sprput(void)
{
	int id, x0, y0, x1, y1, x, y, c;
	struct sprite *sp;
	uint16_t *u16src, *u16dst;
	uint8_t *u8src, *u8dst;

	id = evalint();
	if(getch() != ',')
		error(SYNTAX);
	x0 = evalint();
	if(getch() != ',')
		error(SYNTAX);
	y0 = evalint();
	check();

	SLIST_FOREACH(sp, &spr_head, spr_le)
		if (sp->spr_id == id)
			break;
	if (sp == NULL)
		error(BADDATA);

	x1 = x0 + sp->size_x;
	y1 = y0 + sp->size_y;
	if (x0 < 0)
		x0 = 0;
	if (y0 < 0)
		y0 = 0;
	if (x1 > 512)
		x1 = 512;
	if (y1 > 288)
		y1 = 288;

	if (fb_mode == 0)
		for (y = y0; y < y1; y++) {
			u8src =
			    &((uint8_t *) &sp->data)[(y - y0) * sp->size_x];
			u8dst = (uint8_t *) fb_buff[fb_drawable];
			u8dst += (y << 9) + x0;
			for (x = x0; x < x1; x++) {
				c = *u8src++;
				if (c != sp->spr_trans_color)
					*u8dst = c;
				u8dst++;
			}
		}
	else
		for (y = y0; y < y1; y++) {
			u16src =
			    &((uint16_t *) &sp->data)[(y - y0) * sp->size_x];
			u16dst = (uint16_t *) fb_buff[fb_drawable];
			u16dst += (y << 9) + x0;
			for (x = x0; x < x1; x++) {
				c = *u16src++;
				if (c != sp->spr_trans_color)
					*u16dst = c;
				u16dst++;
			}
		}
	X11_SCHED_UPDATE();
	normret;
}


/* Input function for JPEG decompression */
static UINT
in_func(JDEC* jd, BYTE* buff, UINT nbyte)
{
	IODEV *dev = (IODEV*)jd->device;
	UINT retval;

	if (buff) {
		/* Read bytes from input stream */
		retval = read(dev->fh, buff, nbyte);
	} else {
		/* Remove bytes from input stream */
		retval = lseek(dev->fh, nbyte, SEEK_CUR) ? nbyte : 0;
	}

	return (retval);
}


/* Output funciton for JPEG decompression */
static UINT
out_func(JDEC* jd, void* bitmap, JRECT* rect)
{
	IODEV *dev = (IODEV*)jd->device;
	UINT y, bws;
	BYTE *dst;
#if JD_FORMAT < JD_FMT_RGB32
	BYTE *src;
#else
	LONG *src;
#endif
	uint32_t i, rgb, prev_rgb = 0, color = 0;
	uint16_t *dst16;
	uint8_t *dst8;

	/* Copy the decompressed RGB rectanglar to the frame buffer (assuming RGB888 cfg) */
#if JD_FORMAT < JD_FMT_RGB32
	src = (BYTE*)bitmap;
	/* Width of source rectangular [byte] */
	bws = 3 * (rect->right - rect->left + 1);
#else
	src = (LONG*)bitmap;
	/* Width of source rectangular [byte] */
	bws = (rect->right - rect->left + 1);
#endif
	/* Left-top of destination rectangular */
	dst = dev->fbuf + (fb_mode + 1) * (rect->top * dev->wfbuf + rect->left);
	for (y = rect->top; y <= rect->bottom; y++) {
		if (fb_mode) {
			dst16 = (void *) dst;
#if JD_FORMAT < JD_FMT_RGB32
			for (i = 0; i < bws; i += 3) {
#else
			for (i = 0; i < bws; i++) {
#endif
#if JD_FORMAT < JD_FMT_RGB32
				rgb = src[i] * 65536 +
				    src[i+1] * 256 + src[i+2];
#else
				rgb = src[i];
#endif
				if (rgb != prev_rgb) {
					prev_rgb = rgb;
					color = fb_rgb2pal(rgb);
				}
				*dst16++ = color;
			}
			dst += 2 * dev->wfbuf;
		} else {
			dst8 = (void *) dst;
#if JD_FORMAT < JD_FMT_RGB32
			for (i = 0; i < bws; i += 3) {
#else
			for (i = 0; i < bws; i++) {
#endif
#if JD_FORMAT < JD_FMT_RGB32
				rgb = src[i] * 65536 +
				    src[i+1] * 256 + src[i+2];
#else
				rgb = src[i];
#endif
				if (rgb != prev_rgb) {
					prev_rgb = rgb;
					color = fb_rgb2pal(rgb);
				}
				*dst8++ = color;
			}
			dst += dev->wfbuf;
		}
		src += bws; /* Next line */
	}

	return (1);    /* Continue to decompress */
}


int
loadjpg(void)
{
	char work_buf[8192];
	STR st;
	JDEC jdec;
	JRESULT r;
	IODEV devid;

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(work_buf, st->strval);
	FREE_STR(st);
	check();

	if (fb_mode > 1)
		error(24);	/* out of core */

	devid.fh = open(work_buf, O_RDONLY);
	if (devid.fh < 0)
		error(15);

	r = jd_prepare(&jdec, in_func, work_buf, sizeof(work_buf), &devid);
	if (r == JDR_OK) {
		if (jdec.width > 512 || jdec.height > 288) {
			close(devid.fh);
			error(12); /* buffer size overflow in field */
		}

		devid.fbuf = fb_buff[fb_drawable];
		devid.wfbuf = 512;
		r = jd_decomp(&jdec, out_func, 0);
                if (r != JDR_OK)
                        printf("Failed to decompress: rc=%d\n", r);
	} else {
		printf("Failed to prepare: rc=%d\n", r);
	}
	close(devid.fh);
	X11_SCHED_UPDATE();
	normret;
}
