
#include "asm.h"
#include "regdef.h"
#include "io.h"

	.data

	.set noreorder
	.text

GLOBAL(btext)
ASM_ENTRY(_start)
1:
	lui	gp, (_gp >> 16)
	ori	gp, _gp
	lui	sp, 0x0001
	jal	_C_LABEL(platform_start)
	lui	k1, (IO_BASE >> 16)
	b	1b
	nop
