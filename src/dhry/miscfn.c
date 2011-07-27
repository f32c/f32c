
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void _strcpy(char *, const char *);

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
#if 0
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
#else
	int res;

	__asm (
		".set noreorder			\n"
		"	or	$2, $4, $5	\n"
		"	andi	$2, $2, 0x3	\n"
		"	bnez	$2, 3f		\n"
		"	lui	$6, 0x00ff	\n"
		"	lui	$7, 0xff00	\n"
		"	lw	$2, 0($4)	\n"
		"1:				\n"
		"	lw	$3, 0($5)	\n"
		"	addiu	$4, $4, 4	\n"
		"	bne	$2, $3, 2f	\n"
		"	and	$3, $2, $6	\n"
		"	beqz	$3, 5f		\n"
		"	and	$3, $2, $7	\n"
		"	beqz	$3, 5f		\n"
		"	andi	$3, $2, 0xff00	\n"
		"	beqz	$3, 5f		\n"
		"	andi	$3, $2, 0x00ff	\n"
		"	beqz	$3, 5f		\n"
		"	addiu	$5, $5, 4	\n"
		"	b	1b		\n"
		"	lw	$2, 0($4)	\n"
		"2:				\n"
		"	addiu	$4, $4, -4	\n"
		"3:				\n"
		"	lbu	$2, 0($4)	\n"
		"	lbu	$3, 0($5)	\n"
		"	beqz	$2, 4f		\n"
		"	addiu	$4, $4, 1	\n"
		"	beq	$2, $3, 3b	\n"
		"	addiu	$5, $5, 1	\n"
		"4:				\n"
		"	jr	$31		\n"
		"	subu	$2, $2, $3	\n"
		"5:				\n"
		"	jr	$31		\n"
		"	subu	$2, $2, $2	\n"
		: "=r" (res)
		: "r" (s1), "r" (s2)
	);

	/* XXX revisit return - missing a nop after jr ra */
	return(res);
#endif
}


void
_strcpy(char *dst, const char *src)
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
		".set reorder			\n"
		:
		: "r" (dst), "r" (src)
	);
#endif
}


/* memcpy() is likely to become builtin-inlined for anything but -Os */
void
memcpy(char *dst, const char *src, int len)
{

#if 0
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
#else
	__asm (
		".set noreorder			\n"
		".set noat			\n"
		"	or	$2, $4, $5	\n"
		"	andi	$2, $2, 0x3	\n"
		"	bnez	$2, 2f		\n"
		"1:				\n"
		"	slti	$2, $6, 12	\n"
		"	bnez	$2, 2f		\n"
		"	lw	$2, 0($5)	\n"
		"	lw	$3, 4($5)	\n"
		"	lw	$at, 8($5)	\n"
		"	addiu	$5, $5, 12	\n"
		"	addiu	$4, $4, 12	\n"
		"	sw	$2, -12($4)	\n"
		"	sw	$3, -8($4)	\n"
		"	sw	$at, -4($4)	\n"
		"	b	1b		\n"
		"	addiu	$6, $6, -12	\n"
		"2:				\n"
		"	slti	$2, $6, 4	\n"
		"	bnez	$2, 3f		\n"
		"	lw	$2, 0($5)	\n"
		"	addiu	$5, $5, 4	\n"
		"	addiu	$4, $4, 4	\n"
		"	sw	$2, -4($4)	\n"
		"	b	2b		\n"
		"	addiu	$6, $6, -4	\n"
		"3:				\n"
		"	beqz	$6, 4f		\n"
		"	addiu	$6, $6, -1	\n"
		"	lb	$2, 0($5)	\n"
		"	addiu	$5, $5, 1	\n"
		"	addiu	$4, $4, 1	\n"
		"	b	3b		\n"
		"	sb	$2, -1($4)	\n"
		"4:				\n"
		".set reorder			\n"
		".set at			\n"
		:
		: "r" (dst), "r" (src), "r" (len)
	);
#endif
}
