
#include <sys/param.h>
#include <io.h>
#include <fb.h>

static uint32_t	fb_mode = -1;
static uint8_t	*fb = (void *) FB_BASE;

#define	ABS(a) (((a) < 0) ? -(a) : (a))


void
set_fb_mode(int mode)
{

	if (mode == 1)
		fb_mode = 1;
	else if (mode == 0)
		fb_mode = 0;
	else {
		fb_mode = -1;
		fb = NULL;
	}

	OUTB(IO_FB, fb_mode);
}


#define	FPMUL(x, y) ((int16_t)(((int32_t)x * (int32_t)y) >> 15))
#define	FPDIV(x, y) ((int16_t)(((int32_t)x << 15) / (int32_t) y))
#define	FP_ONE (0x8000)
#define	FP_HALF (0x4000)

#define	NEG_X	0x01
#define	NEG_Y	0x02
#define	SWAP_XY	0x04

static int
atan(int y, int x)
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

	/* compute ratio y/x in 0.15 format. */
	if (x == 0)
		atan = 0;
	else
		atan = FPDIV(y, x) >> 2;

	/* unfold result */
	if (flags & SWAP_XY)
		atan = FP_HALF - atan;

	if (flags & NEG_X)
		atan = FP_ONE - atan;

	if (flags & NEG_Y)
		atan = -atan;

	return (atan);
}


static uint32_t
sqrt(uint32_t r)
{
	uint32_t t, q, b;

	b = 0x40000000;
	q = 0;

	while (b >= 256) {
		t = q + b;
		q >>= 1;
		if (r >= t) {
			r -= t;
			q += b;
		}
		b >>= 2;
	}

	return (q);
}


#define	WR	77	/* 0.299 * 256 */
#define	WB	29	/* 0.114 * 256 */
#define	WG	150	/* 0.586 * 256 */
#define	WU	126	/* 0.492 * 256 */
#define	WV	224	/* 0.877 * 256 */

int
rgb2pal(int r, int g, int b) {
	int color, luma, chroma, saturation;
	int u, v;

	/* Transform RGB into YUV */
	luma = (WR * r + WB * b + WG * g) >> 8;
	u = WU * (b - luma);
	v = WV * (r - luma);

	/* Transform {U, V} cartesian into polar {chroma, saturation} coords */
	chroma = (28 - (atan(u, v) >> 10)) & 0x3f;
	saturation = (sqrt((u * u + v * v) >> 1) + (1 << 13)) >> 14;
	if (__predict_false(saturation > 15))
		saturation = 15;

	if (__predict_true(fb_mode))
		/* 16-bit encoding */
		color = (saturation << 12) | ((chroma >> 1) << 7) | (luma >> 1);
	else {
		/* 8-bit encoding */
		if (saturation > 7)		/* saturated color */
			color = 32 + (luma * 6 / 8 / 32) * 16 + (chroma >> 2);
		else if (saturation > 0)	/* dim color */
			color = 128 + (luma / 32) * 16 + (chroma >> 2);
		else 				/* grayscale */
			color = luma / 8;
	}

	return (color);
}


__attribute__((optimize("-O3"))) void
plot(int x, int y, int color)
{

	int off = (y << 9) + x;
	uint8_t *dp = fb;

	if (__predict_false(y < 0 || y > 287 || fb_mode > 1 || (x >> 9)))
		return;
	
	if (__predict_true(fb_mode != 0))
		*((uint16_t *) &dp[off << 1]) = color;
	else
		dp[off] = color;
}


static __attribute__((optimize("-O3"))) void
plot_internal(int x, int y, int mode_color, uint8_t *dp)
{

	int off = (y << 9) + x;

	if (__predict_false(y < 0 || y > 287 || (x >> 9)))
		return;
	
	if (__predict_true(mode_color < 0))
		*((uint16_t *) &dp[off << 1]) = mode_color;
	else
		dp[off] = mode_color;
}

void
rectangle(int x0, int y0, int x1, int y1, int color)
{
	int x;
	uint16_t *fb16 = (void *) fb;

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
	if (__predict_false(x1 > 511))
		x1 = 511;
	if (__predict_false(y1 > 287))
		y1 = 287;

	if (__predict_true(fb_mode)) {
		color = (color << 16) | (color & 0xffff);
		for (; y0 <= y1; y0++) {
			for (x = x0; x <= x1 && (x & 1); x++)
				fb16[(y0 << 9) + x] = color;
			for (; x < x1; x += 2)
				*((int *) &fb16[(y0 << 9) + x]) = color;
			for (; x <= x1; x++)
				fb16[(y0 << 9) + x] = color;
		}
	} else {
		color = (color << 8) | (color & 0xff);
		color = (color << 16) | (color & 0xffff);
		for (; y0 <= y1; y0++) {
			for (x = x0; x <= x1 && (x & 3); x++)
				fb[(y0 << 9) + x] = color;
			for (; x <= (x1 - 3); x += 4)
				*((int *) &fb[(y0 << 9) + x]) = color;
			for (; x <= x1; x++)
				fb[(y0 << 9) + x] = color;
		}
	}
}


void
line(int x0, int y0, int x1, int y1, int color)
{
	int x, y, dx, dy, dx0, dy0, p, e, i, c, d;

	dx = x1 - x0;
	dy = y1 - y0;
	dx0 = ABS(dx);
	dy0 = ABS(dy);

	if (fb_mode > 1)
		return;
	if (fb_mode != 0)
		color |= 0x80000000;

	if (dy0 <= dx0) {
		c = (dx < 0 && dy < 0) || (dx > 0 && dy > 0);
		d = 2 * dy0 - dx0;
		if (dx >= 0) {
			x = x0;
			y = y0;
			e = x1;
		} else {
			x = x1;
			y = y1;
			e = x0;
		}
		p = d;
		plot_internal(x, y, color, fb);
		for (i = 0; x < e; i++) {
			x++;
			if (p < 0)
				p += 2 * dy0;
			else {
				if (c)
					y++;
				else
					y--;
				p += d;
			}
			plot_internal(x, y, color, fb);
		}
	} else {
		c = (dx < 0 && dy < 0) || (dx > 0 && dy > 0);
		d = 2 * dx0 - dy0;
		if (dy >= 0) {
			x = x0;
			y = y0;
			e = y1;
		} else {
			x = x1;
			y = y1;
			e = y0;
		}
		p = d;
		plot_internal(x, y, color, fb);
		for (i = 0; y < e; i++) {
			y++;
			if (p <= 0)
				p += 2 * dx0;
			else {
				if (c)
					x++;
				else
					x--;
				p += d;
			}
			plot_internal(x, y, color, fb);
		}
	}
}


void
circle(int x0, int y0, int r, int color)
{
	int f = 1 - r;
	int ddF_x = 1;
	int ddF_y = -2 * r;
	int x = 0;
	int y = r;
 
	if (fb_mode > 1)
		return;
	if (fb_mode != 0)
		color |= 0x80000000;

	plot_internal(x0, y0 + r, color, fb);
	plot_internal(x0, y0 - r, color, fb);
	plot_internal(x0 + r, y0, color, fb);
	plot_internal(x0 - r, y0, color, fb);
 
	while(x < y) {
		if (f >= 0) {
			y--;
			ddF_y += 2;
			f += ddF_y;
		}
		x++;
		ddF_x += 2;
		f += ddF_x;    
		plot_internal(x0 + x, y0 + y, color, fb);
		plot_internal(x0 - x, y0 + y, color, fb);
		plot_internal(x0 + x, y0 - y, color, fb);
		plot_internal(x0 - x, y0 - y, color, fb);
		plot_internal(x0 + y, y0 + x, color, fb);
		plot_internal(x0 - y, y0 + x, color, fb);
		plot_internal(x0 + y, y0 - x, color, fb);
		plot_internal(x0 - y, y0 - x, color, fb);
	}
}


void
filledcircle(int x0, int y0, int r, int color)
{
	int f = 1 - r;
	int ddF_x = 1;
	int ddF_y = -2 * r;
	int x = 0;
	int y = r;
 
	plot(x0, y0 + r, color);
	plot(x0, y0 - r, color);
	rectangle(x0 + r, y0, x0 - r, y0, color);
 
	while(x < y) {
		if (f >= 0) {
			y--;
			ddF_y += 2;
			f += ddF_y;
		}
		x++;
		ddF_x += 2;
		f += ddF_x;    
		rectangle(x0 - x, y0 + y, x0 + x, y0 + y, color);
		rectangle(x0 - x, y0 - y, x0 + x, y0 - y, color);
		rectangle(x0 - y, y0 + x, x0 + y, y0 + x, color);
		rectangle(x0 - y, y0 - x, x0 + y, y0 - x, color);
	}
}
