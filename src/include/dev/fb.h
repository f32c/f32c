/*-
 * Copyright (c) 2013 - 2025 Marko Zec, Univeristy of Zagreb
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

struct modeline {
	uint32_t pixclk;
	uint16_t hdisp;
	uint16_t hsyncstart;
	uint16_t hsyncend;
	uint16_t htotal;
	uint16_t vdisp;
	uint16_t vsyncstart;
	uint16_t vsyncend;
	uint16_t vtotal: 13,
		 hsyncn: 1,
		 vsyncn: 1,
		 interlace: 1;
};

#define	FB_MODE_720p60	((void *) 0x0)
#define	FB_MODE_1080i60	((void *) 0x1)
#define	FB_MODE_720p50	((void *) 0x2)
#define	FB_MODE_1080i50	((void *) 0x3)

#define	FB_BPP_MASK	0xf
#define	FB_BPP_OFF	0x0
#define	FB_BPP_1	0x1
#define	FB_BPP_2	0x2
#define	FB_BPP_4	0x3
#define	FB_BPP_8	0x4
#define	FB_BPP_16	0x5
#define	FB_BPP_24	0x6

#define	FB_DOUBLEPIX	0x10

void fb_set_mode(const struct modeline *, int);
void fb_get_mode(const struct modeline **, int *);
void fb_set_drawable(int);
void fb_set_visible(int);

void fb_plot(int, int, int);
void fb_line(int, int, int, int, int);
void fb_rectangle(int, int, int, int, int);
void fb_circle(int, int, int, int);
void fb_filledcircle(int, int, int, int);
void fb_fill(int, int, int);
void fb_text(int, int, const char *, int, int, int);
int fb_rgb2pal(int);

extern uint8_t *fb[];
extern uint8_t *fb_active;
extern uint8_t fb_visible;
extern uint8_t fb_bpp;
extern uint8_t fb_drawable;
extern uint16_t fb_hdisp;
extern uint16_t fb_vdisp;
