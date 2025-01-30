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

#include <fcntl.h>
#include <stdlib.h>

#include <sys/file.h>
#include <sys/tty.h>

#include <dev/io.h>
#include <dev/sio.h>

#define	SIO_RXBUFSIZE	(1 << 5)
#define	SIO_RXBUFMASK	(SIO_RXBUFSIZE - 1)

#define	SIO_REG_DATA	0x0
#define	SIO_REG_STATUS	0x4
#define	SIO_REG_BAUD	0x8

#define	SIO_PORTS	4

extern int fd_ref(struct file *); /* XXX fixinclude */

static int sio_read(struct file *, void *, size_t);
static int sio_write(struct file *, const void *, size_t);

static struct fileops sio_fileops = {
	.fo_read = &sio_read,
	.fo_write = &sio_write,
};

struct sio_state {
	uint32_t	s_io_port;
	uint16_t	s_rxbuf_head; /* Managed by sio_probe_rx() */
	uint16_t	s_rxbuf_tail; /* Managed by sio_read() */
	uint16_t	s_hw_rx_overruns;
	uint16_t	s_sw_rx_overruns;
	char		s_rxbuf[SIO_RXBUFSIZE];
};

static struct tty sio0_tty = {
	.t_termios.c_lflag = ISIG,
	.t_termios.c_iflag = ICRNL | IXON,
	.t_termios.c_oflag = OPOST | ONLCR,
	.t_ws.ws_row = 24,
	.t_ws.ws_col = 80
};

static struct sio_state sio0_state = {
	.s_io_port = IO_SIO_0
};

struct file __sio0_file = {
	.f_ops = &sio_fileops,
	.f_priv = &sio0_state,
	.f_tty = &sio0_tty,
	.f_refc = 3
};

static struct file *sio_files[SIO_PORTS] = {
	&__sio0_file,
};

static uint16_t sio_bauds[16] = {
	3,	6,	12,	24,	48,	96,	192,	384,
	576,	1152,	2304,	4608,	9216,	10000,	15000,	30000
};

static int
sio_close(struct file *fp)
{
	struct sio_state *sio = fp->f_priv;

	sio_files[(sio->s_io_port - IO_SIO_0) / 16] = NULL;

	return (0);
}

int
sio_open(int unit)
{
	struct file *fp;
	struct sio_state *sio;
	int fd;

	if (unit < 0 || unit >= SIO_PORTS || sio_files[unit] != NULL
	    || (sio = calloc(1, sizeof(struct sio_state))) == NULL) {
		errno = EINVAL;
		return (-1);
	}

	fp = calloc(1, sizeof(struct file));
	fd = fd_ref(fp);
	if (fd < 0) {
		free(fp);
		free(sio);
		errno = ENFILE;
		return (fd);
	}

	sio_files[unit] = fp;
	sio->s_io_port = IO_SIO_0 + 16 * unit;
	fp->f_priv = sio;
	fp->f_mflags = F_MF_FILE_MALLOCED | F_MF_PRIV_MALLOCED;
	fp->f_ops = &sio_fileops;
	sio_fileops.fo_close = &sio_close;

	return (fd);
}

static int
sio_probe_rx(struct file *fp)
{
	struct sio_state *sio = fp->f_priv;
	int c, s, rxbuf_head_next;

	for (;;) {
		LB(s, SIO_REG_STATUS, sio->s_io_port);
		if (s >> 4 != 0) {
			sio->s_hw_rx_overruns += (s >> 4) & 0xf;
			SB(0, SIO_REG_STATUS, sio->s_io_port);
		}

		if ((s & SIO_RX_FULL) == 0)
			break;

		LB(c, SIO_REG_DATA, sio->s_io_port);

		if (TTY_DO_IPROC(fp->f_tty, c) &&
		    (c = tty_iproc(fp->f_tty, c)) < 0)
			continue;

		rxbuf_head_next = (sio->s_rxbuf_head + 1) & SIO_RXBUFMASK;
		if (rxbuf_head_next == sio->s_rxbuf_tail) {
			sio->s_sw_rx_overruns++;
			continue;
		}

		sio->s_rxbuf[sio->s_rxbuf_head] = c;
		sio->s_rxbuf_head = rxbuf_head_next;
	}

	return (s & SIO_TX_BUSY);
}

static int
sio_read(struct file *fp, void *buf, size_t nbytes)
{
	struct task *task = TD_TASK(curthread);
	struct sio_state *sio = fp->f_priv;
	char *cbuf = buf;
	int i, empty;

	for (i = 0; i < nbytes;) {
		for (;;) {
			sio_probe_rx(fp);
			empty = sio->s_rxbuf_head == sio->s_rxbuf_tail;
			if (!empty)
				break;
			if (fp->f_flags & O_NONBLOCK) {
				if (i != 0)
					return (i);
				errno = EAGAIN;
				return (-1);
			}
			if (task->ts_sigf & 2) {
				errno = EINTR;
				task->ts_sigf &= ~2;
				return (-1);
			}
			/* XXX TODO: notify system we are blocked, yield() */
		}
		do {
			cbuf[i++] = sio->s_rxbuf[sio->s_rxbuf_tail++];
			sio->s_rxbuf_tail &= SIO_RXBUFMASK;
			empty = sio->s_rxbuf_head == sio->s_rxbuf_tail;
		} while (!empty && i < nbytes);
	}

	return (i);
}

static int
sio_write(struct file *fp, const void *buf, size_t nbytes)
{
	struct task *task = TD_TASK(curthread);
	struct sio_state *sio = fp->f_priv;
	const char *cbuf = buf;
	char tios_obuf[4];
	int tios_i = 0, tios_n = 0;
	int c, i;

	for (i = 0; i < nbytes || tios_i != tios_n;) {
		for (; (sio_probe_rx(fp) & SIO_TX_BUSY) ||
		    (TTY_OBLOCKED(fp->f_tty) && (tios_i == tios_n));) {
			if (fp->f_flags & O_NONBLOCK) {
				if (i != 0)
					return (i);
				errno = EAGAIN;
				return (-1);
			}
			if (task->ts_sigf & 2) {
				errno = EINTR;
				task->ts_sigf &= ~2;
				return (-1);
			}
			/* XXX TODO: notify system we are blocked, yield() */
		}

		if (tios_i != tios_n)
			c = tios_obuf[tios_i++];
		else {
			c = cbuf[i++];
			if (TTY_DO_OPROC(fp->f_tty, c)) {
				tios_i = 0;
				tios_n = tty_oexpand(fp->f_tty, c, tios_obuf);
				if (tios_n == 0)
					continue;
				tios_i = 1;
				c = tios_obuf[0];
			}
		}
		SB(c, SIO_REG_DATA, sio->s_io_port);
	}

	return nbytes;
}


/* Legacy f32c functions, should go away */

#include <unistd.h>

int
sio_getchar(int blocking)
{
	struct file *fp = TD_TASK(curthread)->ts_files[0]; /* XXX */
	int res;
	char c;

	if (!blocking)
		fp->f_flags |= O_NONBLOCK;

	res = read(0, &c, 1);

	if (!blocking)
		fp->f_flags &= ~O_NONBLOCK;

	if (res < 0)
		return (res);
	return (c);
}


int
sio_setbaud(int bauds)
{
	struct file *fp = TD_TASK(curthread)->ts_files[0]; /* XXX */
	struct sio_state *sio = fp->f_priv;
	int i;

	for (i = 0, bauds /= 100; i < 16; i++)
		if (sio_bauds[i] == bauds) {
			SB(i, SIO_REG_BAUD, sio->s_io_port);
			return (0);
		}
	return (-1);
}


int
sio_getbaud(void)
{
	struct file *fp = TD_TASK(curthread)->ts_files[0]; /* XXX */
	struct sio_state *sio = fp->f_priv;
	int i;

	LB(i, SIO_REG_BAUD, sio->s_io_port);
	return (sio_bauds[i] * 100);
}
