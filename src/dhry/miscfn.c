
#include <stdio.h>
#include <stdlib.h>


void *
malloc(int size)
{

	printf("malloc: %d\n\n", size);
	exit(0);
	return(NULL); /* XXX unreached */
}


int
strcmp(const char *s1, const char *s2)
{
	char c1, c2;
 
	do {
		c1 = *s1++;
		c2 = *s2++;
	} while (c1 != 0 && c1 == c2);
	return (c1 - c2);
}


void
strcpy(char *dst, const char *src)
{
	char c;
 
	do {
		c = *src++;
		*dst++ = c;
	} while (c != 0);
}


void
memcpy(char *dst, const char *src, int len)
{

	while (len--)
		*dst++ = *src++;
}

