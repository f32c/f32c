
#include "io.h"
#include "libc.h"

void msleep(int ms)
{
	int ticks, start, current;

	/* approximately ticks = ms * 50000 */
	ticks = (ms << 15) + (ms << 14) + (ms << 9) + (ms << 8);

	INW(start, IO_TSC);
	do {
		INW(current, IO_TSC);
	} while (current - start < (ticks));

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
