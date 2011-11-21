
#include <asm.h>
#include <regdef.h>
#include <io.h>


/*
 * Setup the global pointer register and jump into main().
 *
 * We assume that the stack pointer and the k1 register have been
 * already properly set up for us by the bootloader here.
 */
	.section .text.startup
	.globl _start
	.type _start,@function

_start:
	.set noreorder
	lui	gp, (_gp >> 16)
	j	_C_LABEL(main)
	ori	gp, _gp
