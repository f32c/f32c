
#include <stdio.h>
#include <stdlib.h>


static char malloc_pool[128];
static int malloc_i = 0;

/* XXX this simplified malloc hack only works for the dhrystone benchmark! */
void *
malloc(int size)
{
	void *addr;

	addr = &malloc_pool[malloc_i * 64];
	malloc_i ^= 1;

	return(addr);
}


int
strcmp(const char *s1, const char *s2)
{
	int c1, c2;
 
	/* Check for aligned pointers for faster operation */
	if ((((int)s1 | (int)s2) & 3) == 0) {
		for (; *((int *)s1) == *((int *)s2);) {
			s1 += 4;
			s2 += 4;
		}
	}

	do {
		c1 = *s1++;
		c2 = *s2++;
	} while (c1 != 0 && c1 == c2);
	return (c1 - c2);
}


void
strcpy(char *dst, const char *src)
{
	int c;
 
	/* Check for aligned pointers for faster operation */
	if ((((int)src | (int)dst) & 3) == 0) {
		do {
			c = *((int *)src);
			if ((c & 0x00ff0000) == 0)
				break;
			if ((c & 0x0000ff00) == 0)
				break;
			if ((c & 0x000000ff) == 0)
				break;
			*((int *)dst) = c;
			if ((c & 0xff000000) == 0)
				return;
			src += 4;
			dst += 4;
		} while (1);
	}

	do {
		c = *src++;
		*dst++ = c;
	} while (c != 0);
}


/* memcpy() is likely to become builtin-inlined for anything but -Os */
void
memcpy(char *dst, const char *src, int len)
{

	while (len--)
		*dst++ = *src++;
}
