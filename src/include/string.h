
#ifndef _STRING_H_
#define _STRING_H_


int strcmp(const char *, const char *);


#define memcpy(dst, src, len) _memcpy(dst, src, len)


#define	strcpy(dst, src)					\
	if (sizeof(src) != sizeof(void *))			\
		_memcpy((dst), (src), sizeof(src));		\
	else							\
		_strcpy(dst, src);


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
