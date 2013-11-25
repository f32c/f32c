
#include <string.h>


static char malloc_pool[96]; /* XXX hardcoded 2 * 48 */

static int malloc_i = 0;


/* XXX this simplified malloc hack only works for the dhrystone benchmark! */
void *
malloc(int size)
{
	void *addr;

	addr = &malloc_pool[malloc_i * size];
	malloc_i ^= 1;

	return(addr);
}


#if 0
/* memcpy() and strcpy() are required for -Os builds */
#ifdef memcpy
#undef memcpy
#endif
void
memcpy(char *dst, const char *src, int len)
{

	_memcpy(dst, src, len);
}

void
#ifdef strcpy
#undef strcpy
#endif
strcpy(char *dst, const char *src)
{

	for (; *src != 0;)
		*dst++ = *src++;
}
#endif
