
#include <stdio.h>
#include <stdlib.h>


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


int
strcmp(const char *s1, const char *s2)
{
	int c1, c2;
 
	/* Check for aligned pointers for faster operation */
	if ((((int)s1 | (int)s2) & 3) == 0) {
		for (; (c1 = *((int *)s1)) == *((int *)s2);) {
			if ((c1 & 0x00ff0000) == 0)
				return(0);
			if ((c1 & 0x0000ff00) == 0)
				return(0);
			if ((c1 & 0x000000ff) == 0)
				return(0);
			if ((c1 & 0xff000000) == 0)
				return(0);
			s1 += 4;
			s2 += 4;
		}
	}

	do {
		c1 = *(const unsigned char *)s1++;
		c2 = *(const unsigned char *)s2++;
	} while (c1 != 0 && c1 == c2);
	return (c1 - c2);
}


void
strcpy(char *dst, const char *src)
{
#if 0
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
#else
	__asm (
		".set noreorder			\n"
		"	or	$2, $4, $5	\n"
		"	andi	$2, $2, 0x3	\n"
		"	bnez	$2, 2f		\n"
		"	lui	$6, 0x00ff	\n"
		"	lw	$2, 0($5)	\n"
		"	lui	$7, 0xff00	\n"
		"1:				\n"
		"	and	$3, $2, $6	\n"
		"	beqz	$3, 2f		\n"
		"	andi	$3, $2, 0xff00	\n"
		"	beqz	$3, 2f		\n"
		"	andi	$3, $2, 0x00ff	\n"
		"	beqz	$3, 2f		\n"
		"	sw	$2, 0($4)	\n"
		"	and	$3, $2, $7	\n"
		"	beqz	$3, 3f		\n"
		"	addiu	$5, $5, 4	\n"
		"	addiu	$4, $4, 4	\n"
		"	b	1b		\n"
		"	lw	$2, 0($5)	\n"
		"2:				\n"
		"	lb	$2, 0($5)	\n"
		"	addiu	$5, $5, 1	\n"
		"	addiu	$4, $4, 1	\n"
		"	bnez	$2, 2b		\n"
		"	sb	$2, -1($4)	\n"
		"3:				\n"
		:
		: "r" (dst), "r" (src)
	);
#endif
}


/* memcpy() is likely to become builtin-inlined for anything but -Os */
void
memcpy(char *dst, const char *src, int len)
{

	/* Check for aligned pointers for faster operation */
	if ((((int)src | (int)dst) & 3) == 0) {
		for (; len > 3; len -= 4) {
			*((int *)dst) = *((int *)src);
			src += 4;
			dst += 4;
		}
	}

	while (len--)
		*dst++ = *src++;
}
