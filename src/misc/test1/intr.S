
#include <mips/asm.h>
#include <mips/regdef.h>
#include <mips/cpuregs.h>
#include <io.h>


	nop
	nop
	nop
	nop
	nop
	nop
	nop

VECTOR(MipsException, unknown)
	.set    noat
	li	k0, 0x300
	lw	k1, 0(k0)
	addiu	k1, k1, 1
	sw	k1, 0(k0)
	eret
	nop
	.set    at
VECTOR_END(MipsException)
