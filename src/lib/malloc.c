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

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define MALLOC_DIAGNOSTIC

extern int _end;

static char	**descr_tbl;
static size_t	descr_tbl_len;
static size_t	descr_tbl_max_len;

#define	GET_PTR(ptr)		((char *) (((size_t) (ptr)) & ~1))
#define	GET_FREE(ptr)		(((size_t) (ptr)) & 1)
#define	SET_FREE(ptr, use)	((char *) ((size_t) GET_PTR(ptr) | (use & 1)))

#define	DESCR_INCR_STEP	16
#define	INIT_DESCR_SZ	DESCR_INCR_STEP


static void *
malloc_internal(size_t size)
{
	size_t i, len, best_len = 0;
	int best = -1;

	/* Align request size to word length */
	size = (size + (sizeof(int) - 1)) & ~(sizeof(int) - 1);

	/* Find the smallest free chunk */
	for (i = 0; i < descr_tbl_len - 1; i++)
		if (GET_FREE(descr_tbl[i])) {
			len = GET_PTR(descr_tbl[i + 1]) - GET_PTR(descr_tbl[i]);
			if (len >= size && (best < 0 || len < best_len)) {
				best_len = len;
				best = i;
				if (best_len == size)
					break;
			}
		}

	/* Out of memory */
	if (best < 0)
		return (NULL);

	if (best_len > size) {
		/* Split the free chunk in two */
		if (GET_FREE(descr_tbl[best + 1]) == 0) {
			for (i = descr_tbl_len - 1; i > best; i--)
				descr_tbl[i + 1] = descr_tbl[i];
			descr_tbl_len++;
		}
		descr_tbl[best + 1] = descr_tbl[best] + size;
	}
	descr_tbl[best] = SET_FREE(descr_tbl[best], 0);

	return (descr_tbl[best]);
}


void
free(void *ptr)
{
	size_t i, j, step;

	for (step = i = descr_tbl_len / 2;;) {
		if (step > 1)
			step /= 2;
		if (ptr > (void *) descr_tbl[i])
			i += step;
		else if (SET_FREE(ptr, 1) < descr_tbl[i])
			i -= step;
		else if (descr_tbl[i] == ptr) {
			descr_tbl[i] = SET_FREE(descr_tbl[i], 1);
			/* Attempt to merge adjacent free chunks */
			if (GET_FREE(descr_tbl[i + 1]))
				descr_tbl[i + 1] =
				    SET_FREE(descr_tbl[i + 2], 1);
			while (i > 0 && GET_FREE(descr_tbl[i - 1])) {
				descr_tbl[i] = SET_FREE(descr_tbl[i + 1], 1);
				i--;
			}
			for (j = i; GET_FREE(descr_tbl[j + 1]); j++) {}
#ifdef MALLOC_DIAGNOSTIC
			if (j > i &&
			    GET_PTR(descr_tbl[j]) != descr_tbl[j + 1]) {
				printf("XXX panic %p %p\n",
				    descr_tbl[j], descr_tbl[j + 1]);
				exit(1);
			}
#endif
			if (j > i) {
				do {
					descr_tbl[++i] = descr_tbl[++j];
				} while (j < descr_tbl_len - 1);
				descr_tbl_len -= (j - i);
			}
			return;
		} else
			i++;
#ifdef MALLOC_DIAGNOSTIC
		if (i < 0 || i >= descr_tbl_len) {
			printf("XXX Can't free %p, i = %d\n", ptr, i);
			for (i = 0; i < descr_tbl_len; i++)
				printf("%p\n", descr_tbl[i]);
			exit(1);
		}
#endif
	}
}


void *
malloc(size_t size)
{
	void *new, *old;

	if (size == 0)
		return (NULL);

	if (descr_tbl == NULL) {
		/* init */
		descr_tbl = (void *) &_end;
		descr_tbl[0] = SET_FREE(descr_tbl, 0);
		descr_tbl[1] = SET_FREE(&descr_tbl[INIT_DESCR_SZ], 1);
		descr_tbl[2] = SET_FREE((char *) 0x800f8000, 0);
		descr_tbl_len = 3;
		descr_tbl_max_len = INIT_DESCR_SZ;
	}

	/* Grow descr tbl if necessary */
	if (descr_tbl_len + 2 >= descr_tbl_max_len) {
		new = malloc_internal(sizeof(*descr_tbl) *
		    (descr_tbl_max_len + DESCR_INCR_STEP));
		if (new == NULL)
			return (NULL);
		old = descr_tbl;
		descr_tbl = new;
		memcpy(new, old, descr_tbl_len * sizeof(char *));
		descr_tbl_max_len += DESCR_INCR_STEP;
		free(old);
	}

	return (malloc_internal(size));
}
