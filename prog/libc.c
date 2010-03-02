
#include "io.h"
#include "lcdfunc.h"
#include "libc.h"

int newkey;
int oldkey;

int msleep(int ms)
{
	int ticks, start, current;

	/* approximately ticks = ms * 50000 */
	ticks = (ms << 15) + (ms << 14) + (ms << 9) + (ms << 8);

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

void bcopy(const char *src, char *dst, int len)
{

	for (; len > 0; len--)
		*dst++ = *src++;
}

void memset(char *dst, int c, int len)
{

	for (; len > 0; len--)
		*dst++ = c;
}

int strlen(const char *c)
{
	int len;

	for (len = 0; *c != 0; c++, len++) {}

	return (len);
}
