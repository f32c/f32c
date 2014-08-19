/*-
 * Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
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

#define	SIO_RXBUFSIZE	(1 << 3)
#define	SIO_RXBUFMASK	(SIO_RXBUFSIZE - 1)

static char sio_rxbuf[SIO_RXBUFSIZE];
static uint8_t sio_rxbuf_head;
static uint8_t sio_rxbuf_tail;
static uint8_t sio_tx_xoff;


__attribute__((optimize("-Os"))) int
sio_probe_rx(void)
{
	int c, s;

	INB(s, IO_SIO_STATUS);
	if (s & SIO_RX_FULL) {
		INB(c, IO_SIO_BYTE);
		if (c == 0x13) {
			/* XOFF */
			sio_tx_xoff = 1;
			return(s);
		}
		if (c == 0x11) {
			/* XON */
			sio_tx_xoff = 0;
			return(s);
		}
		sio_rxbuf[sio_rxbuf_head++] = c;
		sio_rxbuf_head &= SIO_RXBUFMASK;
	}
	return(s);
}


__attribute__((optimize("-Os"))) int
sio_getchar(int blocking)
{
	int c, busy;

	/* Any new characters received from RS-232? */
	do {
		sio_probe_rx();
		busy = (sio_rxbuf_head == sio_rxbuf_tail);
	} while (blocking && busy);

	if (busy)
		return (-1);
	c = sio_rxbuf[sio_rxbuf_tail++];
	sio_rxbuf_tail &= SIO_RXBUFMASK;
	return (c);
}


__attribute__((optimize("-Os"))) int
sio_putchar(int c, int blocking)
{
	int in, busy;

	do {
		in = sio_probe_rx();
		busy = (in & SIO_TX_BUSY) || sio_tx_xoff;
	} while (blocking && busy);

	if (busy == 0)
		OUTB(IO_SIO_BYTE, c);
	return (busy);
}
