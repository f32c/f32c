
#include "io.h"
#include "lcdfunc.h"
#include "libc.h"

int newkey;
int oldkey;
int randseed;

int
msleep(int ms)
{
	int ticks, start, current;

	ticks = mul(ms, 50000);

	INW(start, IO_TSC);
	do {
		INW(newkey, IO_LED);
		newkey &= 0x0100; 	/* Rotary knob press-button */
		if (newkey != oldkey) {
			if (newkey)
				return (1);		/* Button pressed */
			else
				oldkey = newkey;	/* Button released */
		}

		lcd_redraw();

		INW(current, IO_TSC);
	} while (current - start < (ticks));

	return (0);
}

void
bcopy(const char *src, char *dst, int len)
{

	for (; len > 0; len--)
		*dst++ = *src++;
}

void
memset(char *dst, int c, int len)
{

	for (; len > 0; len--)
		*dst++ = c;
}

int
strlen(const char *c)
{
	register int len;

	for (len = 0; *c != 0; c++, len++) {}

	return (len);
}

unsigned int
mul(unsigned int a, unsigned int b)
{
	register unsigned int t1 = a;
	register unsigned int t2 = b;
	register unsigned int res = 0;

	while(t1) {
		if(t2 & 1)
			res += t1;
		t1 <<= 1;
		t2 >>= 1;
	}
	return (res);
}

unsigned int
div(unsigned int a, unsigned int b, unsigned int *mod)
{
	register unsigned int t1 = b << 31;
	register unsigned int t2 = b;
	register unsigned int hi = a, lo = 0;
	register int i;

	for (i = 0; i < 32; ++i) {
		lo = lo << 1;
		if (hi >= t1 && t1 && t2 < 2) {
			hi = hi - t1;
			lo |= 1;
		}
		t1 = ((t2 & 2) << 30) | (t1 >> 1);
		t2 = t2 >> 1;
	}
	if(mod)
		*mod = hi;
	return (lo);
}

unsigned int
random()
{
	register int x, t;
	register int hi;
	unsigned int lo;

	/*
	 * Compute x[n + 1] = (7^5 * x[n]) mod (2^31 - 1).
	 * From "Random number generators: good ones are hard to find",
	 * Park and Miller, Communications of the ACM, vol. 31, no. 10,
	 * October 1988, p. 1195.
	 */
	/* Can't be initialized with 0, so use another value. */
	if ((x = randseed) == 0)
		x = 123459876;
#ifdef NOTYET
	hi = x / 127773;
	lo = x % 127773;
#else
	hi = div(x, 127773, &lo);
#endif
	t = 16807 * lo - 2836 * hi;
	if (t < 0)
		t += 0x7fffffff;
	randseed = t;
	return (t);
}
