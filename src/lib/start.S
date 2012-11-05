
#include <mips/asm.h>
#include <mips/regdef.h>
#include <io.h>


/*
 * Setup the global (small data) pointer register and jump into main().
 *
 * We assume that the stack pointer and the k1 register have been
 * already properly set up for us by the bootloader here.
 */
	.section .text.startup
	.globl _start
	.type _start,@function

_start:
	la	gp, _gp
	j	_C_LABEL(main)
