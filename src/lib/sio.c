
#include <sys/param.h>
#include <io.h>
#include <sio.h>

#define	SIO_RXBUFSIZE	16
#define	SIO_RXBUFMASK	0x0f

void (*sio_idle_fn)(void) = NULL;
static char sio_rxbuf[SIO_RXBUFSIZE];
static uint8_t sio_rxbuf_head = 1;
static uint8_t sio_rxbuf_tail = 1;
static uint8_t sio_tx_xoff = 0;


static __attribute__((optimize("-Os"))) int
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
	int c;
	int busy;

	/* Any new characters received from RS-232? */
	do {
		if (sio_idle_fn != NULL)
			(*sio_idle_fn)();
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


__attribute__((optimize("-Os"))) int
sio_putchar(int c, int blocking)
{
	int in;
	int busy;

	do {
		if (sio_idle_fn != NULL)
			(*sio_idle_fn)();
		in = sio_probe_rx();
		busy = (in & SIO_TX_BUSY) || sio_tx_xoff;
	} while (blocking && busy);

	if (busy)
		return (-1);
	else {
		OUTB(IO_SIO_BYTE, c);
		return (0);
	}
}
