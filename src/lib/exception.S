/*-
 * Copyright (c) 2014 Marko Zec, University of Zagreb
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


#define	REGSIZE		4
#define	ISR_STACK_SIZE	4096


	.data

_exception_stack:	.space ISR_STACK_SIZE
_exception_regs:	.space REGSIZE * 29


	.text

/*
 * Prepare register context for executing ISR handlers and call isr_dispatch().
 */
LEAF(_exception_start)
	.set	reorder
	.set	noat

	/* Save register context */
	la	k1, _exception_regs
	sw	$1, (0 * REGSIZE)(k1)
	sw	$2, (1 * REGSIZE)(k1)
	sw	$3, (2 * REGSIZE)(k1)
	sw	$4, (3 * REGSIZE)(k1)
	sw	$5, (4 * REGSIZE)(k1)
	sw	$6, (5 * REGSIZE)(k1)
	sw	$7, (6 * REGSIZE)(k1)
	sw	$8, (7 * REGSIZE)(k1)
	sw	$9, (8 * REGSIZE)(k1)
	sw	$10, (9 * REGSIZE)(k1)
	sw	$11, (10 * REGSIZE)(k1)
	sw	$12, (11 * REGSIZE)(k1)
	sw	$13, (12 * REGSIZE)(k1)
	sw	$14, (13 * REGSIZE)(k1)
	sw	$15, (14 * REGSIZE)(k1)
	sw	$16, (15 * REGSIZE)(k1)
	sw	$17, (16 * REGSIZE)(k1)
	sw	$18, (17 * REGSIZE)(k1)
	sw	$19, (18 * REGSIZE)(k1)
	sw	$20, (19 * REGSIZE)(k1)
	sw	$21, (20 * REGSIZE)(k1)
	sw	$22, (21 * REGSIZE)(k1)
	sw	$23, (22 * REGSIZE)(k1)
	sw	$24, (23 * REGSIZE)(k1)
	sw	$25, (24 * REGSIZE)(k1)
	sw	$28, (25 * REGSIZE)(k1)
	sw	$29, (26 * REGSIZE)(k1)
	sw	$30, (27 * REGSIZE)(k1)
	sw	$31, (28 * REGSIZE)(k1)

	/* Set the exception stack */
	la	sp, _exception_stack
	addiu	sp, sp, ISR_STACK_SIZE

	/* Clear software IRQs, pass masked IRQs to isr_dispatch() */
	mfc0	v0, $MIPS_COP_0_CAUSE
	mfc0	v1, $MIPS_COP_0_STATUS
	and	a0, v1, v0
	srl	a0, a0, 8
	li	a1, ~(MIPS_SOFT_INT_MASK_1 | MIPS_SOFT_INT_MASK_0)
	andi	a0, a0, 0xff
	and	v0, a1, v0
	mtc0	v0, $MIPS_COP_0_CAUSE
	jal	isr_dispatch

	/* Restore register context */
	lw	$1, (0 * REGSIZE)(k1)
	lw	$2, (1 * REGSIZE)(k1)
	lw	$3, (2 * REGSIZE)(k1)
	lw	$4, (3 * REGSIZE)(k1)
	lw	$5, (4 * REGSIZE)(k1)
	lw	$6, (5 * REGSIZE)(k1)
	lw	$7, (6 * REGSIZE)(k1)
	lw	$8, (7 * REGSIZE)(k1)
	lw	$9, (8 * REGSIZE)(k1)
	lw	$10, (9 * REGSIZE)(k1)
	lw	$11, (10 * REGSIZE)(k1)
	lw	$12, (11 * REGSIZE)(k1)
	lw	$13, (12 * REGSIZE)(k1)
	lw	$14, (13 * REGSIZE)(k1)
	lw	$15, (14 * REGSIZE)(k1)
	lw	$16, (15 * REGSIZE)(k1)
	lw	$17, (16 * REGSIZE)(k1)
	lw	$18, (17 * REGSIZE)(k1)
	lw	$19, (18 * REGSIZE)(k1)
	lw	$20, (19 * REGSIZE)(k1)
	lw	$21, (20 * REGSIZE)(k1)
	lw	$22, (21 * REGSIZE)(k1)
	lw	$23, (22 * REGSIZE)(k1)
	lw	$24, (23 * REGSIZE)(k1)
	lw	$25, (24 * REGSIZE)(k1)
	lw	$28, (25 * REGSIZE)(k1)
	lw	$29, (26 * REGSIZE)(k1)
	lw	$30, (27 * REGSIZE)(k1)
	lw	$31, (28 * REGSIZE)(k1)

	mfc0	k0, $MIPS_COP_0_EXC_PC
	ei
	jr	k0
END(_exception_start)


/*
 * Set exception address, enable all interrupts.
 */
LEAF(isr_enable)
	.set	reorder

	la	a0, _exception_start
	mtc0	a0, $MIPS_COP_0_EBASE
	li	a0, MIPS_SR_INT_MASK | MIPS_SR_INT_IE
	mtc0	a0, $MIPS_COP_0_STATUS
	jr	ra
END(isr_enable)
