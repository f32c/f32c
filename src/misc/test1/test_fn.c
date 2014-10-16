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
#include <io.h>
#include <stdlib.h>
#include <stdio.h>


typedef int fn1_t(int, uint32_t *);
fn1_t fn1;

int
fn1(int a, uint32_t *p32)
{

#if 1
	volatile uint32_t *p = p32;

	/* Ovo radi krivo iz SRAM-a bez (utreniranog) branch predictora */
	/* fix: r1094 */
	for (int i = 0; i < 3; i++)
		*p += a + (*p >> 3);
#endif

#if 0
	/* Ne cancelira se bnel delay slot */
	/* fix: r1095 */
	__asm __volatile (
		".set noreorder;"
		"li %0, 0;"
		"bnel $0, $0, 1f;"
		"li %0, 1;"
		"addiu %0, %0, 0x10;"
		"1:;"
		"addiu %0, %0, 0x100;"
		".set reorder;"
		: "=r" (a)
		: "r" (a), "r" (p32)
        );
#endif

#if 0
	/* Ne cancelira se instrukcija iza beql delay slota */
	/* fix: r1095 */
	__asm __volatile (
		".set noreorder;"
		"li %0, 0;"
		"beql $0, $0, 1f;"
		"li %0, 1;"
		"addiu %0, %0, 0x10;"
		"1:;"
		"addiu %0, %0, 0x100;"
		".set reorder;"
		: "=r" (a)
		: "r" (a), "r" (p32)
        );
#endif

	return (a);
}
