
#ifndef _STRING_H_
#define _STRING_H_

#include <types.h>


#define	memcpy(dst, src, len) _memcpy(dst, src, len)

#define	strcpy(dst, src)					\
	if (sizeof(src) != sizeof(void *))			\
		_memcpy((dst), (src), sizeof(src));		\
	else							\
		_strcpy(dst, src);


static inline int
strcmp(const char *s1, const char *s2)
{
	int c1, c2;
	uint32_t v0;
	const uint32_t t0 = 0x01010101;
	const uint32_t t1 = 0x80808080;

	/* Check for aligned pointers for faster operation on 32-bit words */
	if ((((int)s1 | (int)s2) & 3) == 0) {
		/* Loop until words do not match */
		for (;;) {
			/* Check whether words are equal */
			c1 = *((int *)s1);
			c2 = *((int *)s2);
			if (c1 != c2) {
				c1 &= 0xff;
				c2 &= 0xff;
				if (c1 == 0 || c1 != c2)
					return (c1 - c2);
				c1 = *(const unsigned char *)(s1 + 1);
				c2 = *(const unsigned char *)(s2 + 1);
				if (c1 == 0 || c1 != c2)
					return (c1 - c2);
				c1 = *(const unsigned char *)(s1 + 2);
				c2 = *(const unsigned char *)(s2 + 2);
				if (c1 == 0 || c1 != c2)
					return (c1 - c2);
				c1 = *(const unsigned char *)(s1 + 3);
				c2 = *(const unsigned char *)(s2 + 3);
				return (c1 - c2);
			}
			/* Check if the word contains any zero bytes */
			v0 = (((uint32_t)c1) - t0) & t1;
			if (v0) {
				/* Maybe */           
				if (v0 & ~((uint32_t)c1)) 
					return(0);
			}
			s1 += 4;
			s2 += 4;
		}
	} else {
		do {
			c1 = *(const unsigned char *)s1++;
			c2 = *(const unsigned char *)s2++;
		} while (c1 != 0 && c1 == c2);
		return (c1 - c2);
	}
}


static inline void
_memcpy(char *dst, const char *src, int len)
{

	while (len--)
		*dst++ = *src++;
}


static inline void
_strcpy(char *dst, const char *src)
{
	int c;

	do {
		c = *src++;
		*dst++ = c;
	} while (c != 0);
}

#endif /* !_STRING_H_ */
