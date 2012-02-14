
#include <sys/param.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


static char malloc_pool[128];
static int malloc_i = 0;


/* XXX this simplified malloc hack only works for the dhrystone benchmark! */
void *
malloc(int size __attribute__((unused)))
{
	void *addr;

	addr = &malloc_pool[malloc_i * 64];
	malloc_i ^= 1;

	return(addr);
}


/* memcpy() is required for -Os builds */
#ifdef memcpy
#undef memcpy
#endif
void
memcpy(char *dst, const char *src, int len)
{

	_memcpy(dst, src, len);
}

int memcpy_cnt;
