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
		";" // XXX MZ fixme riscv
#endif
		: "=r" (sp), "=r" (pc)
	);

	/* Find out this function's stack frame size, and adjust sp */
	for (i = 0;; i += 4) {
		instr = *((uint32_t *) ((uint32_t) bt) + i);
		if (instr >> 16 == 0x27bd) /* addiu sp, sp, intoff */
			break;
	}
	sp_off = instr & 0xffff;
	sp -= sp_off;

next_frame:
	pc -= 8;
	for (i = 0; __fntab[i].name != NULL; i++)
		if (__fntab[i].base >= pc)
			break;

	if (i == 0 || __fntab[i].name == NULL)
		return;
	i--;

	printf("0x%08x: %s() + 0x%x\n", pc, __fntab[i].name,
	    pc - __fntab[i].base);

	/* Find out stack frame size and where the return address is stored */
	for (ra_off = 0, sp_off = 0; pc >= __fntab[i].base; pc -= 4) {
		instr = *((uint32_t *) pc);
		switch (instr >> 16) {
		case 0xafbf: /* sw ra, off(sp) */
			ra_off = instr & 0xffff;
			break;
		case 0x27bd: /* addiu sp, sp, intoff*/
			sp_off = instr & 0xffff;
			break;
		default:
		}
	}

	pc = *((uint32_t *) (sp + ra_off));
	sp -= sp_off;
	goto next_frame;
}
