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

#include <sys/isr.h>


int isr_cnt;


static int
test_isr(int irq)
{
	int i;

	isr_cnt++;
	OUTB(IO_LED, isr_cnt >> 10);

	if (irq == 2) {
		/* Clear the 50 Hz framebuffer interrupt */
if ((isr_cnt & 0xfff) == 0)
		INB(i, IO_FB);
	}

	if (irq == 3) {
		/* Clear the sio interrupt */
		INB(i, IO_SIO_STATUS);
		if (i & SIO_RX_FULL) {
			INB(i, IO_SIO_BYTE);
			OUTB(IO_SIO_BYTE, i);
		} else
			return (0);
	}

	return (1);
}


struct isr_link test_fb_isr = {
	.handler_fn = &test_isr
};

struct isr_link test_sio_isr = {
	.handler_fn = &test_isr
};


void
main(void)
{
	int i = 0;

	isr_register_handler(2, &test_fb_isr);
	isr_register_handler(3, &test_sio_isr);
	__asm("ei");

	volatile int *a = &isr_cnt;
	do {
		if (*a > i) {
			printf("\r%d", *a);
			i = *a;
		}
		__asm("wait");
	} while (1);
}
