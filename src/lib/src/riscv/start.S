/*-
 * Copyright (c) 2013-2015 Marko Zec, University of Zagreb
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


/*
 * Clear BSS, set small data index register and jump into main().
 *
 * Assumes that the loader has already properly:
 * 1) set stack pointer
 * 2) set return address
 * 3) invalidated caches
 */
	.section .init
	.globl _start
	.type _start,@function

_start:
	la	gp, _gp	
	la	s1, _end	/* End of BSS section, word aligned */
	la	s0, __bss_start	/* Start of BSS section, NOT word aligned */

	/* The loader doesn't bzero the BSS, so we must do it here. */
bss_bzero:
	sb	zero, (s0)
	addi	s0, s0, 1
	bne	s0, s1, bss_bzero

	la	s0, __init_array_start
	la	s1, _fdata
	move	s2, ra
	b	ctor_loop_enter

ctor_loop:
	lw	a0, (s0)
	addi	s0, s0, 4
	jalr	a0
ctor_loop_enter:
	bne	s0, s1,	ctor_loop
	move	ra, s2
	j	main
