/*-
 * Copyright (c) 2013 Marko Zec
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

#include <sys/param.h>
#include <fb.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>

#include <mips/asm.h>
#include <mips/atomic.h>


static __inline void
lock_spin(__volatile uint32_t *p)
{

	do {} while (atomic_cmpset_32(p, 0, 1) == 0);
}


static __inline void
unlock_spin(__volatile uint32_t *p)
{

	*p = 0;
}


volatile uint32_t	*lockp;
uint32_t		lock_mem;


void
thread(int cpuid)
{
	int tmp, x0, y0, x1, y1, color;

	do {
		lock_spin(lockp);
		printf("%d ", cpuid);
		unlock_spin(lockp);

		tmp = random();
                x0 = tmp & 0x1ff;
                y0 = ((tmp >> 16) & 0x7f) + (cpuid << 7) + 16;
                color = (tmp >> 27);
                tmp = random();
                x1 = tmp & 0x1ff;
                y1 = ((tmp >> 16) & 0x7f) + (cpuid << 7) + 16;
                color ^= (tmp >> 13);
                line(x0, y0, x1, y1, color);
	} while (1);
}


int
main(void)
{
	int i, r, cpuid;
	volatile uint32_t *p = (void *) 0x80080000;

	lockp = &lock_mem;
	set_fb_mode(1);		/* 16-bitna paleta */

	mfc0_macro(cpuid, MIPS_COP_0_CONFIG);
	cpuid &= 0xf;

	printf("Hello, world from CPU #%d\n", cpuid);
	
	if (cpuid > 0) {
		/* This will execute only on CPU #1 */
		do {
			atomic_add_32(p, 1);
			atomic_add_32(p, 1);
			atomic_add_32(p, 1);
		} while (*lockp == 0);

		thread(cpuid);
	}

	printf("Starting CPU #1...\n");
	*p = 0;
	OUTB(IO_CPU_RESET, ~3);

	/* Wait for CPU #1 to become active */
	do {} while (*p == 0);

	printf("Loop starting on CPU #0...\n");
	for (i = 0; i < 1000000; i++) {
		atomic_clear_32(p, 0xffffffff);
		r = *p;
		if (r > 0)
			printf("%d:%d ", i, r);
	}
	printf("\n");

	thread(cpuid);

	printf("Stopping CPU #1...\n");
	OUTB(IO_CPU_RESET, ~1);

	return (0);
}
