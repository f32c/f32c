
#include <io.h>
#include <sio.h>

#define	SIO_RXBUFSIZE	16
#define	SIO_RXBUFMASK	0x0f

static char sio_rxbuf[SIO_RXBUFSIZE];
static int sio_rxbuf_head = 1;
static int sio_rxbuf_tail = 1;


static int
sio_probe_rx(void)
{
	int c;

	INW(c, IO_SIO);
	if (c & SIO_RX_BYTES) {
		sio_rxbuf[sio_rxbuf_head++] = c >> 8;
		sio_rxbuf_head &= SIO_RXBUFMASK;
	}
	return(c);
}


int
sio_getchar(int blocking)
{
	int c;
	int busy;

	/* Any new characters received from RS-232? */
	do {
		sio_probe_rx();
		busy = (sio_rxbuf_head == sio_rxbuf_tail);
	} while (blocking && busy);

	if (busy)
		return (-1);
	else {
		c = sio_rxbuf[sio_rxbuf_tail++];
		sio_rxbuf_tail &= SIO_RXBUFMASK;
		return (c);
	}
}


int
sio_putchar(int c, int blocking)
{
	int in;
	int busy;

	do {
		in = sio_probe_rx();
		busy = (in & SIO_TX_BUSY);
	} while (blocking && busy);

	if (busy)
		return (-1);
	else {
		OUTB(IO_SIO, c);
		return (0);
	}
}
