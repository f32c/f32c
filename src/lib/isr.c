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

#include <stdio.h>
#include <sys/isr.h>


static SLIST_HEAD(, isr_link) isr_registry[8];


void
isr_dispatch(int filtered_irqs)
{
	int irq, serviced;
	struct isr_link *isrl;

	for (irq = 0; filtered_irqs != 0; filtered_irqs >>= 1, irq++) {
		if ((filtered_irqs & 1) == 0)
			continue;
		serviced = 0;
		SLIST_FOREACH(isrl, &isr_registry[irq], isr_le)
			serviced += isrl->handler_fn();
		if (serviced == 0) {
			printf("Stray IRQ #%d, disabling.\n", irq);
			disable_irq(irq);
		}
	}
}


void
isr_register_handler(int irq, struct isr_link *isr_entry)
{
	
	SLIST_INSERT_HEAD(&isr_registry[irq], isr_entry, isr_le);
	enable_irq(irq);
}
