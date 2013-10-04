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

#include <io.h>
#include <types.h>
#include <stdio.h>


extern void pcm_play(void);


int
main(void)
{
	int a = 1;
	
	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

#ifdef STANDARD_MIPS32_ISA
	printf("\n\nStart test - MIPS32 ISA movn / movz\n");

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movn $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n1 (30)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movn $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n2 (0)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movn $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n3 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movz $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z1 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movz $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z2 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movz $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z3 (30)	a = %d\n", a);

#else	/* F32C ISA */
	printf("\n\nStart test - F32C ISA movn / movz\n");

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movn $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n1 (30)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movn $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n2 (0)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movn $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n3 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movz $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z1 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movz $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z2 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movz $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z3 (30)	a = %d\n", a);
#endif

	return (0);
}
