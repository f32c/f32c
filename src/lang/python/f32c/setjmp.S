/*-
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD: stable/9/lib/libstand/mips/_setjmp.S 182290 2008-08-27 17:58:51Z obrien $
 */

#include <mips/asm.h>
#include <mips/regdef.h>
#include <mips/cpuregs.h>

/*
 * C library -- _setjmp, _longjmp
 *
 *	_longjmp(a,v)
 * will generate a "return(v)" from
 * the last call to
 *	_setjmp(a)
 * by restoring registers from the stack,
 * The previous signal state is NOT restored.
 */

LEAF(setjmp)
	.set	noreorder
	li	v0, 0xACEDBADE			# sigcontext magic number
	sw	ra, (2 * 4)(a0)			# sc_pc = return address
	sw	v0, (3 * 4)(a0)			#   saved in sc_regs[0]
	sw	s0, (4 * 4)(a0)
	sw	s1, (5 * 4)(a0)
	sw	s2, (6 * 4)(a0)
	sw	s3, (7 * 4)(a0)
	sw	s4, (8 * 4)(a0)
	sw	s5, (9 * 4)(a0)
	sw	s6, (10 * 4)(a0)
	sw	s7, (11 * 4)(a0)
	sw	sp, (12 * 4)(a0)
	sw	s8, (13 * 4)(a0)
	jr	ra
	move	v0, zero
END(setjmp)

LEAF(longjmp)
#ifdef ABICALLS 
	subu	sp, sp, 32
	.cprestore 16
#endif  
	.set    noreorder
	lw	ra, (2 * 4)(a0)
	lw	v0, (3 * 4)(a0)			# get magic number
	bne	v0, 0xACEDBADE, botch		# jump if error
	addu	sp, sp, 32			# does not matter, sanity
	lw	s0, (4 * 4)(a0)
	lw	s1, (5 * 4)(a0)
	lw	s2, (6 * 4)(a0)
	lw	s3, (7 * 4)(a0)
	lw	s4, (8 * 4)(a0)
	lw	s5, (9 * 4)(a0)
	lw	s6, (10 * 4)(a0)
	lw	s7, (11 * 4)(a0)
	lw	sp, (12 * 4)(a0)
	lw	s8, (13 * 4)(a0)
	jr	ra
	move	v0, a1
botch:
	jal	_C_LABEL(longjmperror)
	nop
//	jal	_C_LABEL(abort)
	jr	zero
	nop
END(longjmp)
