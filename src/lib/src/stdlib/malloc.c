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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


extern void *_end;

static uint32_t *heap;

#define	GET_LEN(len)	((len) & ~0x80000000)
#define	IS_FREE(len)	((len) & 0x80000000)
#define	SET_FREE(len)	((len) | 0x80000000)


//#define MALLOC_DEBUG

#ifdef MALLOC_DEBUG
static int free_cnt = 1;
static int used_cnt = 0;
#endif

/*
 * Each chunk is preceeded by a 4-byte length & type descriptor.  Length
 * value stored in the descriptor is a sum of the payload length (rounded
 * to multiplies of 4) and the size of the descriptor.  The most significant
 * bit indicates chunk type, which can be either used (0) or free (1).
 */


static void
malloc_init()
{
	int i, val, done = 0;
	uint32_t off, ram_top;
	volatile uint32_t *probe;

	/* Attempt to guess the amount of available RAM, max 256 MB */
	probe = heap = (void *) &_end;
	off = 1024;
	for (i = -1; i < 2 && off < (1 << 28) / sizeof(*heap); i++) {
		val = probe[off];
		probe[off] = ~val;
		if (probe[off] != ~val)
			done = 1;
		probe[off] = val;
		if (done)
			break;
		*probe = i;
		if (probe[off] != i) {
			off <<= 1;
			i = -2;
		}
	}
	ram_top = (uint32_t) &heap[off] - (((uint32_t) heap) & ~(1 <<31));

	/* Reserve stack space depending on memory mapping */
	if ((int) ram_top < 0)
		ram_top -= 0x2000; /* 0x80000000 (XRAM), 8 K */
	else
		ram_top -= 0x1000; /* 0x00000000 (BRAM), 4 K */

	if (ram_top > (uint32_t) heap) {
		i = (ram_top - ((uint32_t) heap)) / sizeof(*heap) - 1;
		probe = heap;
		probe[0] = SET_FREE(i);
	} else
		i = 0;

	heap[i] = 0;
}


void
free(void *ptr)
{
	uint32_t i, len;

	if (ptr == NULL)
		return;

	i = ((uint32_t *) ptr) - heap - 1;
	len = heap[i];
	if (IS_FREE(len)) {
		printf("free(%p): block already free!\n", ptr);
		exit(1);
	}

	/* Attempt to merge with next free block */
	while (IS_FREE(heap[i + len])) {
		len += GET_LEN(heap[i + len]);
#ifdef MALLOC_DEBUG
		free_cnt--;
#endif
	}
	heap[i] = SET_FREE(len);
#ifdef MALLOC_DEBUG
	free_cnt++;
	used_cnt--;
	printf("free(%p): used %d free %d\n", ptr, used_cnt, free_cnt);
#endif
}


void *
malloc(size_t size)
{
	uint32_t i;
	int best_i, best_len;

	if (size == 0)
		return (NULL);

	size = ((size + 3) >> 2) + 1;

	if (heap == NULL)
		malloc_init();

	/* Find free block, linear search, slow. */
	best_i = -1;
	for (i = 0; GET_LEN(heap[i]) > 0; i += GET_LEN(heap[i])) {
		if (IS_FREE(heap[i]) && GET_LEN(heap[i]) >= size &&
		    (best_i < 0 || GET_LEN(heap[i]) <= best_len)) {
			best_i = i;
			best_len = GET_LEN(heap[i]);
			if (best_len == size)
				break;
		}
	}

	/* Out of memory */
	if (best_i < 0)
		return (NULL);

	heap[best_i] = size;
	if (best_len > size)
		heap[best_i + size] = SET_FREE(best_len - size);
#ifdef MALLOC_DEBUG
	else
		free_cnt--;

	used_cnt++;
	printf("malloc(%d): used %d free %d\n", (size - 1) * 4,
	    used_cnt, free_cnt);
#endif
	return (&heap[best_i + 1]);
}


void *
realloc(void *oldptr, size_t size)
{
	uint32_t i, copysize;
	void *newptr;

	newptr = malloc(size);
	if (oldptr != NULL && newptr != NULL) {
		i = ((uint32_t *) oldptr) - heap - 1;
		copysize = GET_LEN(heap[i]);
		if (size < copysize)
			copysize = size;
		memcpy(newptr, oldptr, copysize);
	}
	free(oldptr);
	return (newptr);
}
