
#include <string.h>


static char malloc_pool[96]; /* XXX hardcoded 2 * 48 */

static int malloc_i = 0;


/* XXX this simplified malloc hack only works for the dhrystone benchmark! */
void *
malloc(int size)
{
	void *addr;

	addr = &malloc_pool[malloc_i];
	malloc_i ^= 48;

	return(addr);
}


/* a proper memcpy() function apparently is faster then inlined version */
#ifdef memcpy
#undef memcpy
#endif
void
memcpy(char *dst, const char *src, int len)
{

	_memcpy(dst, src, len);
}
