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
 */

#include <dev/io.h>
#include <dev/sio.h>

#define	SIO_RXBUFSIZE	(1 << 5)
#define	SIO_RXBUFMASK	(SIO_RXBUFSIZE - 1)

static char sio_rxbuf[SIO_RXBUFSIZE];
static uint32_t sio_rxbuf_head; /* Managed by sio_probe_rx() */
static uint32_t sio_rxbuf_tail; /* Managed by sio_getchar() */
static uint8_t sio_tx_xoff;

uint32_t sio_hw_rx_overruns;
uint32_t sio_sw_rx_overruns;


__attribute__((optimize("-Os"))) int
sio_probe_rx(void)
{
	uint32_t c, s, sio_rxbuf_head_next;

	do {
		INB(s, IO_SIO_STATUS);
		if (s >> 4 != 0) {
			sio_hw_rx_overruns += (s >> 4) & 0xf;
			OUTB(IO_SIO_STATUS, 0);
		}

		s &= (SIO_TX_BUSY | SIO_RX_FULL);
		if ((s & SIO_RX_FULL) == 0)
			return (s);

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

		sio_rxbuf_head_next = (sio_rxbuf_head + 1) & SIO_RXBUFMASK;
		if (sio_rxbuf_head_next == sio_rxbuf_tail) {
			sio_sw_rx_overruns++;
			continue;
		}

		sio_rxbuf[sio_rxbuf_head] = c;
		sio_rxbuf_head = sio_rxbuf_head_next;
	} while (1);
}


__attribute__((weak, optimize("-Os"))) int
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


__attribute__((weak, optimize("-Os"))) int
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
