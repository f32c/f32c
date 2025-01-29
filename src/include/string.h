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
 */

#ifndef	_STRING_H_
#define	_STRING_H_

char *strcat(char * __restrict, const char * __restrict);
char *strstr(const char *, const char *) __pure;
char *strtok(char * __restrict, const char * __restrict);
char *strtok_r(char *, const char *, char **);
int strncmp(const char *, const char *, size_t);
size_t strlcpy(char * restrict, const char * restrict, size_t);
size_t strlcat(char * restrict, const char * restrict, size_t);

void *memchr(const void *, int, size_t) __pure;
void *memmove(void *, const void *, size_t);
void *memset(void *, int, size_t);
int memcmp(const void *, const void *, size_t) __pure;

#define	memcpy(dst, src, len) _memcpy((dst), (src), (len))
#define	strncpy(dst, src, len) __builtin_strncpy((dst), (src), (len))
#define	strrchr(buf, ch) __builtin_strrchr((buf), (ch))

int strcmp(const char * __restrict, const char * __restrict);
#define	strcpy(dst, src) __builtin_strcpy((dst), (src))


static inline void
bzero(void *dst, int len)
{
	char *cp = (char *) dst;

	while (len--)
		*cp++ = 0;
}

static inline void *
_memcpy(void *dst, const void *src, int len)
{
	char *dst1 = (char *) dst;
	const char *src1 = (const char *) src;

	if ((((int)dst | (int)src) & 3) == 0) {
		while (len >= 4) {
			*((uint32_t *) dst1) = *((uint32_t *) src1);
			dst1 += 4;
			src1 += 4;
			len -= 4;
		}
	}

	while (len--)
		*dst1++ = *src1++;

	return (dst);
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

	for (u.cp = p;; ++u.p) {
		if (*u.p == ch)
			return(u.p);
		if (*u.p == '\0')
			return(NULL);
	}
	/* NOTREACHED */
}

#endif /* !_STRING_H_ */
