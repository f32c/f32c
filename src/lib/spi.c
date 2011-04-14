
#include <io.h>


int
spi_byte(int out)
{
	int i, io, in = 0;

	for (i = 0; i < 8; i++) {
		if (out & 0x80)
			io = SPI_SI;
		else
			io = 0;
		OUTB(IO_SPI, io);
		out <<= 1;
		OUTB(IO_SPI, io | SPI_SCK);
		in <<= 1;
		INB(io, IO_SPI);
		if (io & SPI_SO)
			in |= 1;
	}
	OUTB(IO_SPI, 0);
	return (in);
}


void
spi_start_transaction(void)
{

	OUTB(IO_SPI, 0);
	return;
}


void
spi_stop_transaction(void)
{

	OUTB(IO_SPI, SPI_CEN);
	return;
}

