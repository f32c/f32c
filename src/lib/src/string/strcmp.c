/*-
 * Copyright (c) 2013 - 2023 Marko Zec
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

#include <string.h>

#define UNROLLED_STRCMP


int
strcmp(const char *s1, const char *s2)
{
	int c1, c2;
	int b1, b2;
	uint32_t v0;

	if (__predict_false(((int)s1 | (int)s2) & 0x3)) {
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
#ifndef UNROLLED_STRCMP
		s1 += 4;
		s2 += 4;
#endif
		v0 = ((uint32_t)c1) - 0x01010101;
		if (c1 != c2)
			break;
		v0 &= 0x80808080;
		/* Check if the word contains any zero bytes */
		if (v0 && __predict_false(v0 & ~((uint32_t)c1))) 
			return(0);
#ifdef UNROLLED_STRCMP
		/* Check whether words are equal */
		c1 = *((int *)s1 + 1);
		c2 = *((int *)s2 + 1);
		s1 += 8;
		s2 += 8;
		v0 = ((uint32_t)c1) - 0x01010101;
		if (c1 != c2)
			break;
		v0 &= 0x80808080;
		/* Check if the word contains any zero bytes */
		if (v0 && __predict_false(v0 & ~((uint32_t)c1))) 
			return(0);
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
}
