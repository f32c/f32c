
#include <sys/param.h>
#include <io.h>


void rectangle(int x0, int y0, int x1, int y1, int color);

static int	fb_mode;
static uint8_t	*fb8 = (void *) FB_BASE;
static uint16_t	*fb16 = (void *) FB_BASE;


void
set_fb_mode(int mode)
{

	if (mode)
		fb_mode = 1;
	else
		fb_mode = 0;

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
sqrt(uint32_t r) {
	uint32_t t, q, b;

	b = 0x40000000;
	q = 0;

	while( b >= 256 ) {
		t = q + b;
		q = q / 2;     /* shift right 1 bit */
		if( r >= t ) {
			r = r - t;
			q = q + b;
		}
		b = b / 4;     /* shift right 2 bits */
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
	if (saturation > 15)
		saturation = 15;

	if (fb_mode) {
		/* 16-bit encoding */
		color = (saturation << 12) | ((chroma >> 1) << 7) | (luma >> 1);
	} else {
		/* 8-bit encoding */
		if (saturation > 6) {
			/* saturated color */
			color = 128 + (luma / 16) * 16 + (chroma >> 2);
		} else if (saturation > 1) {
			/* dim color */
			color = 32 + (luma * 6 / 8 / 16) * 16 + (chroma >> 2);
		} else {
			/* grayscale */
			color = luma / 8;
		}
	}

	return (color);
}


void
rectangle(int x0, int y0, int x1, int y1, int color)
{
	int tmp, x, yoff;

	if (x1 < x0) {
		tmp = x0;
		x0 = x1;
		x1 = tmp;
	}
	if (y1 < y0) {
		tmp = y0;
		y0 = y1;
		y1 = tmp;
	}

	if (fb_mode) {
		/* 16-bit encoding */
		while (y0 <= y1) {
			yoff = y0 * 512;
			for (x = x0; x <= x1; x++)
				fb16[yoff + x] = color;
			y0++;
		}
	} else {
		/* 8-bit encoding */
		while (y0 <= y1) {
			yoff = y0 * 512;
			for (x = x0; x <= x1; x++)
				fb8[yoff + x] = color;
			y0++;
		}
	}
}
