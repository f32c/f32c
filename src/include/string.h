
#ifndef _STRING_H_
#define _STRING_H_

#define memcpy(dst, src, len) _memcpy(dst, src, len)

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

#define	strcpy(dst, src)					\
	if (sizeof(src) != sizeof(void *))			\
		memcpy((dst), (src), sizeof(src));		\
	else							\
		_strcpy(dst, src);

#endif /* !_STRING_H_ */
