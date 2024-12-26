/*-
 * Copyright (c) 2013 - 2024 Marko Zec
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

#include <sys/file.h>

#include <dev/io.h>
#include <dev/sio.h>

#define	SIO_RXBUFSIZE	(1 << 5)
#define	SIO_RXBUFMASK	(SIO_RXBUFSIZE - 1)

#define	SIO_BYTE	0x0
#define	SIO_STATUS	0x4
#define	SIO_BAUD	0x8

struct sio_state {
	char		s_rxbuf[SIO_RXBUFSIZE];
	uint32_t	s_io_port;
	uint32_t	s_rxbuf_head; /* Managed by sio_probe_rx() */
	uint32_t	s_rxbuf_tail; /* Managed by sio_getchar() */
	uint32_t	s_hw_rx_overruns;
	uint32_t	s_sw_rx_overruns;
	uint8_t		s_tx_xoff;
};

static struct sio_state sio0_state;

static int
sio_probe_rx(struct file *sfd)
{
	struct sio_state *sio = sfd->f_priv;
	uint32_t c, s, rxbuf_head_next;

	do {
		INB(s, IO_SIO_STATUS);
		if (s >> 4 != 0) {
			sio->s_hw_rx_overruns += (s >> 4) & 0xf;
			OUTB(IO_SIO_STATUS, 0);
		}

		s &= (SIO_TX_BUSY | SIO_RX_FULL);
		if ((s & SIO_RX_FULL) == 0)
			return (s);

		INB(c, IO_SIO_BYTE);
		if (c == 0x13) {
			/* XOFF */
			sio->s_tx_xoff = 1;
			return(s);
		}
		if (c == 0x11) {
			/* XON */
			sio->s_tx_xoff = 0;
			return(s);
		}

		rxbuf_head_next = (sio->s_rxbuf_head + 1) & SIO_RXBUFMASK;
		if (rxbuf_head_next == sio->s_rxbuf_tail) {
			sio->s_sw_rx_overruns++;
			continue;
		}

		sio->s_rxbuf[sio->s_rxbuf_head] = c;
		sio->s_rxbuf_head = rxbuf_head_next;
	} while (1);
}

static int
sio_read(struct file *fp, char *buf, size_t nbytes)
{

	return 0;
}

static int
sio_write(struct file *fp, char *buf, size_t nbytes)
{

	return 0;
}

static struct fileops sio_fileops = {
	.fo_read = &sio_read,
	.fo_write = &sio_write,
};

static struct file sio0_file = {
	.f_ops = &sio_fileops,
	.f_priv = &sio0_state,
	.f_refc = 3
};


/* Legacy f32c functions, should go away */

int
sio_getchar(int blocking)
{
	struct file *sfd = &sio0_file; /* XXX fixme */
	struct sio_state *sio = sfd->f_priv;
	int c, busy;

	/* Any new characters received from RS-232? */
	do {
		sio_probe_rx(sfd);
		busy = (sio->s_rxbuf_head == sio->s_rxbuf_tail);
	} while (blocking && busy);

	if (busy)
		return (-1);
	c = sio->s_rxbuf[sio->s_rxbuf_tail++];
	sio->s_rxbuf_tail &= SIO_RXBUFMASK;
	return (c);
}


int
sio_putchar(int c, int blocking)
{
	struct file *sfd = &sio0_file; /* XXX fixme */
	struct sio_state *sio = sfd->f_priv;
	int in, busy;

	do {
		in = sio_probe_rx(sfd);
		busy = (in & SIO_TX_BUSY) || sio->s_tx_xoff;
	} while (blocking && busy);

	if (busy == 0)
		OUTB(IO_SIO_BYTE, c);
	return (busy);
}
