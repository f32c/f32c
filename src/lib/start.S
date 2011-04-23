
#include <asm.h>
#include <regdef.h>
#include <io.h>

	.set noreorder
	.text

/*
 * Setup the global pointer register and jump into main().
 *
 * We assume that the stack pointer and the k1 register have been
 * already properly set up for us by the bootloader here.
 */
GLOBAL(btext)
ASM_ENTRY(_start)
	lui	gp, (_gp >> 16)
	ori	gp, _gp
	j	_C_LABEL(main)
	lui	k1, (IO_BASE >> 16)
