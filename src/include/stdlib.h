/*-
 * Copyright (c) 2013 Marko Zec, University of Zagreb
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

#ifndef _STDLIB_H_
#define	_STDLIB_H_


double strtod(const char * __restrict, char ** __restrict);
long strtol(const char * __restrict, char ** __restrict, int);
unsigned long strtoul(const char * __restrict, char ** __restrict, int);

void qsort(void *, size_t, size_t, int (*)(const void *, const void *));

#define rand() random()
uint32_t random(void);
void srand(unsigned);

int atoi(const char *);

void *malloc(size_t size);
void *realloc(void *ptr, size_t size);
void free(void *ptr);

#define	alloca(sz) __builtin_alloca(sz)

#define	EXIT_FAILURE	1
#define	EXIT_SUCCESS	0

#define	RAND_MAX	0x7fffffff

char	*getenv(const char *);

/* XXX exit() works only on CPU #0 - fixme! */
_Noreturn static inline void
exit(int x __unused)
{

	while (1) {
		__asm __volatile (
#ifdef __mips__
			".set noreorder\n"
			"jr $0\n"
			"mtc0 $0, $12"	/* Mask and disable all interrupts */
#else /* riscv */
			"jr zero\n"
#endif
		);
	}
}

#endif /* !_STDLIB_H_ */
