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

#include <mips/asm.h>
#include <mips/regdef.h>
#include <mips/cpuregs.h>
#include <io.h>


/*
 * Setup the SP and global (small data) pointer register and jump into main().
 */
	.section .init
	.globl _start
	.type _start,@function

_start:
	/* Magic block required by the FAT bootloader, otherwise harmless */
	la	s0, _start	/* Executable code base address */
	la	s1, _end	/* End of BSS section */

#ifdef BRAM
#ifdef ONLY_I_ROM
	li	sp, 0x80100000	/* SRAM top */
#else
	li	sp, 0x00010000	/* 64 k */
#endif
#else
	/* Invalidate the entire I-cache */
	li	t1, 8192 / 4
	lui	t0, 0x8000
flush_loop:
	addiu	t1, t1, -1
	cache	0, 0(t0)
	addiu	t0, t0, 4
	bgtz	t1, flush_loop

	/* Set up stack pointer, depending on CPU ID */
	mfc0	t0, $MIPS_COP_0_CONFIG
	andi	t0, t0, 0xf	/* CPUID is in 4 LS bits */
	sll	t0, t0, 13	/* 8 k for each CPU should be enough */
	li	sp, 0x80100000
	subu	sp, sp, t0
#endif

	la	gp, _gp

#ifdef ONLY_I_ROM
	/* No ctor walk / support when data memory cannot be read */
	j	_C_LABEL(main)
#else
	la	s0, __init_array_start
	la	s1, _fdata
	move	s2, ra
	b	ctor_loop_enter
	.set noreorder
ctor_loop:
	jalr	a0
	addiu	s0, s0, 4
ctor_loop_enter:
	bne	s0, s1,	ctor_loop
	lw	a0, (s0)
	j	_C_LABEL(main)
	move	ra, s2
	.set reorder
#endif
