/*-
 * Copyright (c) 2013 Marko Zec
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

#include <sys/param.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


int
ref_strcmp(const char *s1, const char *s2)
{

	while (*s1 == *s2++)
		if (*s1++ == 0)
			return (0);
	return (*(const unsigned char *)s1 - *(const unsigned char *)(s2 - 1));
}


int
main(void)
{
	char a[32], b[32];
	int i, j;

	printf("\n");

	do {
		for (i = 0; i < 31; i++) {
			a[i] = (random() & 0x3f) + ' ';
			b[i] = a[i];
		}

		if (((i = random()) & 0xff00) == 0xff00)
			a[i & 0x1f] = (random() & 0x3f) + ' ';

		a[(random() >> 3) & 0x1f] = 0;
		b[(random() >> 3) & 0x1f] = 0;

		i = strcmp(a, b);
		if (i < 0)
			i = -1;
		if (i > 0)
			i = 1;
		j = ref_strcmp(a, b);
		if (j < 0)
			j = -1;
		if (j > 0)
			j = 1;

		if (i != j)
			printf("%s\n%s\n%d %d\n", a, b,
			    strcmp(a, b), ref_strcmp(a, b));
	} while (1);

	return(0);
}
