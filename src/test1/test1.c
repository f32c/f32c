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
#include <stdlib.h>

#include <mips/asm.h>


#define	RDEPC(var) mfc0_macro(var, MIPS_COP_0_EXC_PC);
#define	RDEBASE(var) mfc0_macro(var, MIPS_COP_0_EBASE);

int isr_cnt;


void isr_test(void)
{
	__asm __volatile (
		".set noreorder\n"
		// testing - incr. dummy counter
		"la $26, %0\n"		// k0 <- &isr_cnt
		"lw $27, ($26)\n"	// k1 <- *isr_cnt
		"addiu $27, $27, 1\n"	// k1++
		"sw $27, ($26)\n"	// *isr_cnt <= k1
		// bail out from interrupt
		"mfc0 $27, $14\n"	// k1 <- MIPS_COP_0_EXC_PC
		"jr $27\n"
		"ei\n"
		".set reorder"
		: : "m" (isr_cnt)
	);
}

void epc_test1(void)
{

	__asm __volatile (
		".set noreorder\n"
		"jr $31\n"
		"syscall\n"
		".set reorder"
	);
}

int cnt = 0;

int rt(void);

void *
rdepc(void)
{
	void *x;

	RDEPC(x);
	return (x);
}

void
main(void)
{
	void *epc;

	printf("Setting ISR address...\n");
	epc = &isr_test;
	__asm __volatile (
		"mtc0 %0, $15\n"	// MIPS_COP_0_EBASE <- &isr_test
		"li $1, 0xff00\n"	// interrupt mask - all enabled
		"mtc0 $1, $12"		// MIPS_COP_0_STATUS <- 0xff00
                : : "r" (epc)
	);

	epc = NULL;
	RDEPC(epc);
	printf("EPC = %p\n", epc);
	epc = NULL;
	RDEBASE(epc);
	printf("EBASE = %p\n", epc);

	printf("Enabling interrupts...\n");
	__asm __volatile ("ei");

#if 1
	/* Testing interrupts */
	int i = 0;
	int c = -1;
	volatile int *a = &isr_cnt;
	do {
		epc = rdepc();
		if (*a > c + 20000) {
			c = *a;
			printf(" %p %d %d", epc, c, i);
			printf(" A %d", random());
			printf(" B %d", random());
			printf(" C %d", random());
			printf(" D %d\n", random());
		}
		i++;
		putchar(8);
		if (i == 16)
			i = 0;
		putchar(8);
		if (i < 10)
			putchar('0' + i);
		else
			putchar('a' + i - 10);
	} while (1);
#endif

	printf("Uncached instruction stream:\n");
again:
	__asm __volatile (
		".set noreorder\n"
		"li $27, 1\n"
		"syscall\n"
		"nop\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("%d - sequential code: %p\n", isr_cnt, epc);

	__asm __volatile ("syscall");
	sio_getchar(0);
	RDEPC(epc);
	printf("%d - before jal: %p\n", isr_cnt, epc);

	epc_test1();
	RDEPC(epc);
	printf("%d - jump delay slot: %p\n", isr_cnt, epc);

	__asm __volatile (
		".set noreorder\n"
		"b 1f\n"
		"syscall\n"
		"nop\n"
		"1:\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("%d - taken branch delay slot: %p\n", isr_cnt, epc);

	__asm __volatile (
		".set noreorder\n"
		"beql $0,$27,1f\n"
		"syscall\n"
		"1:\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("%d " "- after delay / nullify slot of untaken branch likely"
	    ": %p\n", isr_cnt, epc);

	__asm __volatile (
		".set noreorder\n"
		"beq $0,$27,1f\n"
		"syscall\n"
		"1:\n"
		".set reorder"
	);
	RDEPC(epc);
	printf("%d - delay slot of untaken branch: %p\n", isr_cnt, epc);

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
