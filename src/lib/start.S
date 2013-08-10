
#include <mips/asm.h>
#include <mips/regdef.h>
#include <mips/cpuregs.h>
#include <io.h>


/*
 * Setup the SP and global (small data) pointer register and jump into main().
 */
	.section .text.unlikely
	.globl _start
	.type _start,@function

_start:
	/* Start with a nop, just in case */
	nop

	/* Invalidate the entire I-cache */
	li	t1, 4096 / 4
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
	li	sp, 0x80010000
	subu	sp, sp, t0

	la	gp, _gp
	j	_C_LABEL(main)
	nop
