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

#include <io.h>
#include <stdio.h>

#include <mips/asm.h>


#define	RDEPC(var)	__asm __volatile ("move %0, $27"	\
                : "=r" (var))	/* outputs */

void isr_test(void)
{
	__asm __volatile (
		".set noreorder\n"
		"addiu $27, $27, 4\n"
		"jr $27\n"
		"ei\n"
		".set reorder"
	);
}

void epc_test1(void)
{

	__asm __volatile (
		".set noreorder\n"
		"jr $31\n"
		"syscall\n"
		"nop\n"
		"nop\n"
		"nop\n"
		"nop\n"
		"nop\n"
		"addiu $27, $27, 4096\n"
		".set reorder"
	);
}

static int cnt = 0;

void
main(void)
{
	void *epc;

	printf("Setting ISR address...\n");
	epc = &isr_test;
	__asm __volatile ("move $26, %0"	\
                : : "r" (epc));

	printf("Enabling interrupts...\n");
	__asm __volatile ("ei\n");

	printf("Uncached instruction stream:\n");
again:
	__asm __volatile (
		".set noreorder\n"
		"li $27, 1\n"
		"syscall\n"
		"addiu $27, $27, 16384\n"
		"1:\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("#1 - sequential code: %p\n", epc);

	__asm __volatile ("syscall");
	sio_getchar(0);
	RDEPC(epc);
	printf("#2 - before jal: %p\n", epc);

	epc_test1();
	RDEPC(epc);
	printf("#3 - jump delay slot: %p\n", epc);

	__asm __volatile (
		".set noreorder\n"
		"b 1f\n"
		"syscall\n"
		"nop\n"
		"1:\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("#4 - taken branch delay slot: %p\n", epc);

	__asm __volatile (
		".set noreorder\n"
		"beql $0,$27,1f\n"
		"syscall\n"
		"1:\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("#5 " "- after delay / nullify slot of untaken branch likely"
	    ": %p\n", epc);

	__asm __volatile (
		".set noreorder\n"
		"beq $0,$27,1f\n"
		"syscall\n"
		"1:\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("#6 - delay slot of untaken branch: %p\n", epc);

	printf("\n");
	cnt++;
	if (cnt == 2) {
		printf("Clearing I-cache...\n");
		__asm __volatile ("j _start");
	}
	if (cnt <= 3) {
		printf("Cached instruction stream:\n");
		goto again;
	}
	printf("Done, disabling interrupts...\n\n");
	__asm __volatile ("di");

	__asm __volatile  ("j $0");
}
