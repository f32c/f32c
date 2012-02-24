
#ifndef	_STRING_H_
#define	_STRING_H_


#define	memcpy(dst, src, len) _memcpy(dst, src, len)

#ifdef USE_BUILTIN_STRCPY
/* XXX this works on pure SWL / SWR luck (unimplemented instructions!) */
#define	strcpy(dst, src) __builtin_strcpy((dst), (src))
#else
#define	strcpy(dst, src)					\
	if (sizeof(src) != sizeof(void *))			\
		_memcpy((dst), (src), sizeof(src));		\
	else							\
		_strcpy(dst, src);
#endif


static inline int
strcmp(const char *s1, const char *s2)
{
	int c1, c2;
#ifdef FASTER_STRCMP
	int b1, b2;
#endif
	uint32_t v0;
	const uint32_t t0 = 0x01010101;
	const uint32_t t1 = 0x80808080;

	/* Check for unaligned pointers */
	if (((int)s1 | (int)s2) & 0x3) {
#ifndef FASTER_STRCMP
slow:
#endif
		do {
			c1 = *(const unsigned char *)s1++;
			c2 = *(const unsigned char *)s2++;
		} while (c1 != 0 && c1 == c2);
		return (c1 - c2);
	}

	for (;;) {
		/* Check whether words are equal */
		c1 = *((int *)s1);
		c2 = *((int *)s2);
		v0 = ((uint32_t)c1) - t0;
		if (c1 != c2) {
#ifdef FASTER_STRCMP
#if _BYTE_ORDER == _LITTLE_ENDIAN
			b1 = c1 & 0xff;
			b2 = c2 & 0xff;
			if (b1 == 0 || b1 != b2)
				return (b1 - b2);
			b1 = (c1 >> 8) & 0xff;
			b2 = (c2 >> 8) & 0xff;
			if (b1 == 0 || b1 != b2)
				return (b1 - b2);
			b1 = (c1 >> 16) & 0xff;
			b2 = (c2 >> 16) & 0xff;
			if (b1 == 0 || b1 != b2)
				return (b1 - b2);
			b1 = (c1 >> 24) & 0xff;
			b2 = (c2 >> 24) & 0xff;
			return (b1 - b2);
#elif _BYTE_ORDER == _BIG_ENDIAN
			b1 = (c1 >> 24) & 0xff;
			b2 = (c2 >> 24) & 0xff;
			if (b1 == 0 || b1 != b2)
				return (b1 - b2);
			b1 = (c1 >> 16) & 0xff;
			b2 = (c2 >> 16) & 0xff;
			if (b1 == 0 || b1 != b2)
				return (b1 - b2);
			b1 = (c1 >> 8) & 0xff;
			b2 = (c2 >> 8) & 0xff;
			if (b1 == 0 || b1 != b2)
				return (b1 - b2);
			b1 = c1 & 0xff;
			b2 = c2 & 0xff;
			return (b1 - b2);
#else
#error "Unsupported byte order."
#endif
#else
			goto slow;
#endif
		}
		v0 &= t1;
		/* Check if the word contains any zero bytes */
		if (v0) {
			/* Maybe */           
			if (__predict_false(v0 & ~((uint32_t)c1))) 
				return(0);
		}
		s1 += 4;
		s2 += 4;
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


static inline void
bzero(void *dst, int len)
{
	char *cp = (char *) dst;

	while (len--)
		*cp++ = 0;
}


static inline int
strlen(const char *str)
{
	const char *cp;

	for (cp = str; *cp; cp++);

	return(cp - str);
}
#endif /* !_STRING_H_ */
