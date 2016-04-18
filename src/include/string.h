/*-
 * Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id$
 */

#ifndef	_STRING_H_
#define	_STRING_H_

char *strstr(const char *, const char *) __pure;

void *memchr(const void *, int, size_t) __pure;
void *memmove(void *, const void *, size_t);
void *memset(void *, int, size_t);
int memcmp(const void *, const void *, size_t) __pure;

#define	memcpy(dst, src, len) _memcpy((dst), (src), (len))
#define	strncpy(dst, src, len) __builtin_strncpy((dst), (src), (len))
#define	strrchr(buf, ch) __builtin_strrchr((buf), (ch))

#ifdef USE_BUILTIN_STRCPY
#define	strcpy(dst, src) __builtin_strcpy((dst), (src))
#else
#if 0
#define	strcpy(dst, src)					\
	if (sizeof(src) != sizeof(void *))			\
		_memcpy((dst), (src), sizeof(src));		\
	else							\
		_strcpy(dst, src);
#else
#define	strcpy(dst, src)	 _strcpy(dst, src);
#endif
#endif


static inline int
strcmp(const char *s1, const char *s2)
{
	int c1, c2;
#ifdef FAST_STRCMP
	int b1, b2;
	uint32_t v0;
	const uint32_t t0 = 0x01010101;
	const uint32_t t1 = 0x80808080;

	/* Check for unaligned pointers */
	if (__predict_false(((int)s1 | (int)s2) & 0x3)) {
#endif /* FAST_STRCMP */
		do {
			c1 = *(const unsigned char *)s1++;
			c2 = *(const unsigned char *)s2++;
		} while (c1 != 0 && c1 == c2);
		return (c1 - c2);
#ifdef FAST_STRCMP
	}

	for (;;) {
		/* Check whether words are equal */
		c1 = *((int *)s1);
		c2 = *((int *)s2);
		v0 = ((uint32_t)c1) - t0;
		if (c1 != c2)
			break;
		v0 &= t1;
		/* Check if the word contains any zero bytes */
		if (v0 && __predict_false(v0 & ~((uint32_t)c1))) 
			return(0);
#ifndef UNROLLED_STRCMP
		s1 += 4;
		s2 += 4;
#else
		/* Check whether words are equal */
		c1 = *((int *)s1 + 1);
		c2 = *((int *)s2 + 1);
		v0 = ((uint32_t)c1) - t0;
		if (c1 != c2)
			break;
		v0 &= t1;
		/* Check if the word contains any zero bytes */
		if (v0 && __predict_false(v0 & ~((uint32_t)c1))) 
			return(0);
		s1 += 8;
		s2 += 8;
#endif
	}

#if _BYTE_ORDER == _LITTLE_ENDIAN
	b1 = c1 & 0xff;
	b2 = c2 & 0xff;
	if (__predict_false(b1 == 0 || b1 != b2))
		return (b1 - b2);
	b1 = c1 & 0xff00;
	b2 = c2 & 0xff00;
	if (b1 == 0 || b1 != b2)
		return (b1 - b2);
	c1 >>= 16;
	c2 >>= 16;
	b1 = c1 & 0xff;
	b2 = c2 & 0xff;
	if (__predict_false(b1 == 0 || b1 != b2))
		return (b1 - b2);
	b1 = c1 & 0xff00;
	b2 = c2 & 0xff00;
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
	b1 = c1 & 0xff00;
	b2 = c2 & 0xff00;
	if (b1 == 0 || b1 != b2)
		return (b1 - b2);
	b1 = c1 & 0xff;
	b2 = c2 & 0xff;
	return (b1 - b2);
#else
#error "Unsupported byte order."
#endif
#endif /* FAST_STRCMP */
}


static inline void
_memcpy(void *dst, const void *src, int len)
{
	char *dst1 = (char *) dst;
	const char *src1 = (const char *) src;

	while (len--)
		*dst1++ = *src1++;
}


static inline char *
_strcpy(char *dst, const char *src)
{
	char *ret = dst;
	int c;

	do {
		c = *src++;
		*dst++ = c;
	} while (c != 0);

	return(ret);
}


static inline void
bzero(void *dst, int len)
{
	char *cp = (char *) dst;

	while (len--)
		*cp++ = 0;
}


static inline size_t
strlen(const char *str)
{
	const char *cp;

	for (cp = str; *cp; cp++);

	return(cp - str);
}


#define	index(p, ch) strchr((p), (ch))

static inline char *
strchr(const char *p, int ch)
{
	union {
		const char *cp;
		char *p;
	} u;

	u.cp = p;
	for (;; ++u.p) {
		if (*u.p == ch)
			return(u.p);
		if (*u.p == '\0')
		return(NULL);
	}
	/* NOTREACHED */
}


static inline int
strncmp(const char *s1, const char *s2, size_t n)
{
 
	if (n == 0)
		return (0);
	do {
		if (*s1 != *s2++)
			return (*(const unsigned char *)s1 -
				*(const unsigned char *)(s2 - 1));
		if (*s1++ == 0)
			break;
	} while (--n != 0);
	return (0);
}

#endif /* !_STRING_H_ */
