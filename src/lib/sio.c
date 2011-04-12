
#include <io.h>
#include <sio.h>


int
sio_getchar(void)
{
	register int c;

	do {
		INW(c, IO_SIO);
	} while ((c & SIO_RX_BYTES) == 0);

	return (c >> 8);
}

void
sio_putchar(int c)
{
	register int status;

	do {
		INW(status, IO_SIO);
	} while (status & SIO_TX_BUSY);
	OUTB(IO_SIO, c);
}
