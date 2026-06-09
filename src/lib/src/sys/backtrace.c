/*-
 * Copyright (c) 2026 Marko Zec
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <execinfo.h>
#include <stdio.h>

/* Must be overriden by the linker */
__asm(".weak __fntab;");

extern struct {
	unsigned int base;
	char *name;
} __fntab[];


void
bt(void)
{
	uint32_t sp, pc, instr;
	int i;
	int16_t ra_off, sp_off;

	/* Fetch this function's stack pointer and return address */
	__asm __volatile__(
#ifdef __mips
		"move %0, $29;"	// sp
		"move %1, $31;"	// ra
#else
		"move %0, sp;"	// sp
		"move %1, ra;"	// ra
#endif
		: "=r" (sp), "=r" (pc)
	);

	/* Find out this function's stack frame size, and adjust sp */
	for (i = 0;; i += 4) {
		instr = *((uint32_t *) ((uint32_t) bt) + i);
#ifdef __mips
		if (instr >> 16 == 0x27bd) /* addiu sp, sp, intoff */
#else
		if ((instr & 0xfffff) == 0x10113) /* addi sp, sp, intoff */
#endif
			break;
	}
#ifdef __mips
	sp_off = instr & 0xffff;
#else
	sp_off = ((int) instr) >> 20;
#endif

next_frame:
	sp -= sp_off;
#ifdef __mips
	pc -= 8;
#else
	pc -= 4;
#endif

	for (i = 0; __fntab[i].name != NULL; i++) {
		if (__fntab[i].base >= pc)
			break;
	}

	if (i == 0 || __fntab[i].name == NULL)
		return;
	i--;

	printf("0x%08x: %s() + 0x%x\n", pc, __fntab[i].name,
	    pc - __fntab[i].base);

	/* Find out stack frame size and where the return address is stored */
	for (ra_off = 0, sp_off = 0; pc >= __fntab[i].base; pc -= 4) {
		instr = *((uint32_t *) pc);
#ifdef __mips
		if ((instr >> 16) == 0xafbf) /* sw ra, off(sp) */
			ra_off = instr & 0xffff;
		else if ((instr >> 16) == 0x27bd) /* addiu sp, sp, intoff*/
			sp_off = instr & 0xffff;
#else
		if ((instr & 0x1ff07f) == 0x112023) /* sw ra, off(sp) */
			ra_off = ((((int) instr) >> 25) << 5) |
			    ((instr >> 7) & 0x1f);
		else if ((instr & 0xfffff) == 0x10113) /* addi sp, sp, off */
			sp_off = ((int) instr) >> 20;
#endif
	}

	pc = *((uint32_t *) (sp + ra_off));
	goto next_frame;
}
