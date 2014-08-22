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
#include <sio.h>
#include <sys/isr.h>

#define	SIO_RXBUFSIZE	(1 << 4)
#define	SIO_RXBUFMASK	(SIO_RXBUFSIZE - 1)

static int sio_rx_isr(void);

struct isr_link sio_isr_link = {
	.handler_fn = &sio_rx_isr
};

static char sio_rxbuf[SIO_RXBUFSIZE];
static uint8_t sio_rxbuf_head;	/* Managed by sio_rx_isr() */
static uint8_t sio_rxbuf_tail;	/* Managed by sio_getchar() */
static uint8_t sio_tx_xoff;
static uint8_t sio_isr_registered;


static __attribute__((optimize("-Os"))) int
sio_rx_isr(void)
{
	int c, s;

	INB(s, IO_SIO_STATUS);
	if ((s & SIO_RX_FULL) == 0)
		return (0);

	INB(c, IO_SIO_BYTE);
	if (c == 0x13) {
		/* XOFF */
		sio_tx_xoff = 1;
		return (1);
	}
	if (c == 0x11) {
		/* XON */
		sio_tx_xoff = 0;
		return (1);
	}
	sio_rxbuf[sio_rxbuf_head++] = c;
	sio_rxbuf_head &= SIO_RXBUFMASK;
	return(1);
}


static void
sio_register_isr(void)
{

	sio_isr_registered = 1;
	asm("di");
	isr_register_handler(3, &sio_isr_link);
	asm("ei");
}


__attribute__((optimize("-Os"))) int
sio_getchar(int blocking)
{
	int c, busy;
	volatile uint8_t *head_ptr = &sio_rxbuf_head;

	if (!sio_isr_registered)
		sio_register_isr();

	do {
		busy = (*head_ptr == sio_rxbuf_tail);
		if (!blocking && busy)
			return (-1);
		if (busy)
			asm("wait");
	} while (busy);

	c = sio_rxbuf[sio_rxbuf_tail++];
	sio_rxbuf_tail &= SIO_RXBUFMASK;
	return (c);
}


__attribute__((optimize("-Os"))) int
sio_putchar(int c, int blocking)
{
	int s, busy;
	volatile uint8_t *xoff_ptr = &sio_tx_xoff;

	do {
		INB(s, IO_SIO_STATUS);
		busy = (s & SIO_TX_BUSY) || *xoff_ptr;
	} while (blocking && busy);

	if (busy == 0)
		OUTB(IO_SIO_BYTE, c);
	return (busy);
}
