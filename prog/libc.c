
#include "io.h"
#include "lcdfunc.h"
#include "libc.h"

int newkey;
int oldkey;
int keymask = 0x0100;		/* Rotary knob press-button */
int rotpos = 63;
int randseed;

int
msleep(int ms)
{
	int ticks, start, current;

	ticks = mul(ms, CPU_FREQ / 1000);

	INW(start, IO_TSC);
	do {
		INW(newkey, IO_LED);
		if ((newkey & keymask) != (oldkey & keymask)) {
			if (newkey & keymask)
				return (1);
			else
				oldkey = newkey;
		}

		lcd_redraw();

		INW(current, IO_TSC);
	} while (current - start < (ticks));

	return (0);
}

void
bcopy(const char *src, char *dst, int len)
{
	int *wsrc = (int *) src;
	int *wdst = (int *) dst;

	/* Check if src and dst are word aligned */
	if (len >= 4 && (((int) src | (int) wdst) & 0x3) == 0) {
		do {
			*wdst++ = *wsrc++;
			len -= 4;
		} while (len >= 4);
		src = (char *) wsrc;
		dst = (char *) wdst;
	}
	for (; len > 0; len--)
		*dst++ = *src++;
}

void
memset(char *dst, int c, int len)
{
	int *wdst = (int *) dst;
	int wc;

	/* Check if dst is word aligned */
	if (len >= 4 && (((int) dst) & 0x3) == 0) {
		wc = (c << 8) + c;
		wc = (wc << 16) + wc;
		do {
			*wdst++ = wc;
			len -= 4;
		} while (len >= 4);
		dst = (char *) wdst;
	}
	for (; len > 0; len--)
		*dst++ = c;
}

int
strlen(const char *c)
{
	int *wcp = (int *) c;
	int len = 0;
	int wc = 0; 	/* Appease gcc warnings */

	/* Check if c is word aligned */
	if ((((int) c) & 0x3) == 0) {
		do {
			if ((len & 0x3) == 0)
				wc = *wcp++;
			else
				wc = wc >> 8;
			if ((wc & 0xff) == 0)
				return (len);
			len++;
		} while (1);
	} else {
		do {
			if (*c == 0)
				return (len);
			len++;
			c++;
		} while (1);
	}
}

unsigned int
mul(unsigned int a, unsigned int b)
{
	unsigned int t1 = a;
	unsigned int t2 = b;
	unsigned int res = 0;

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
	unsigned int t1 = b << 31;
	unsigned int t2 = b;
	unsigned int hi = a, lo = 0;
	int i;

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
	int x, t;
	int hi;
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

char *
itoa(int x, char *buf)
{
	register char *buf1, *buf2;
	register int hi;
	unsigned int lo;
	char c;

	if (x < 0) {
		*buf++ = '-';
		x = ~x + 1;
	}

	buf1 = buf;
	hi = x;

	do {
#ifdef NOTYET
		hi = hi / 10;
		lo = hi % 10;
#else
		hi = div(hi, 10, &lo);
#endif
		*buf1++ = '0' + lo;
	} while (hi);

	/* Reverse characters */
	for (buf2 = --buf1; buf2 > buf;) {
		c = *buf;
		*buf++ = *buf2;
		*buf2-- = c;
	}
	
	return (++buf1);
}

void
itox(int x, char *buf)
{
	int i, j;

	for (i = 0; i < 8; i++) {
		j = (x >> 28) & 0x0f;
		x = x << 4;
		if (j > 9)
			*buf++ = 'W' + j;
		else
			*buf++ = '0' + j;
	}
}

int
printf(const char *fmt, ...)
{
#define	PCHAR(c)	{retval++;}
	int retval = 0;
	int c, n;
	char *cp;
	va_list ap;
	//char buf[16];	/* XXX not to small, not too large - revisit */
 
	va_start(ap, fmt);
	while (true) {
		while ((c = (u_char)*fmt++) != '%') {
			if (c == '\0') {
				va_end(ap);
				return (retval);
			}
                        PCHAR(c);
                }
		switch (c = (u_char)*fmt++) {
		case '%':
			PCHAR(c);
			break;
		case 'd':
		case 'i':
			break;
		case 'u':
			break;
		case 'o':
			break;
		case 'x':
		case 'X':
			break;
		case 'p':
			break;
		case 'c':
			PCHAR(va_arg(ap, int));
			break;
		case 's':
			cp = va_arg(ap, char *);
			n = strlen(cp);
			while (n--)
				PCHAR(*p++);
			break;
		}
	}
}
