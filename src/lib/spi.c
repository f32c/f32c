
#include <io.h>


int
spi_byte_in(void)
{
	int i, io, in = 0;

	for (i = 8; i > 0; i--) {
		OUTB(IO_SPI, SPI_SCK);
		in <<= 1;
		INB(io, IO_SPI);
		in |= (io & SPI_SO);
		OUTB(IO_SPI, 0);
	}
	return (in >> SPI_SO_BITPOS);
}


int
spi_byte(int out)
{
	int i, io, in = 0;

	for (i = 8; i > 0; i--) {
		if (out & 0x80)
			io = SPI_SI;
		else
			io = 0;
		OUTB(IO_SPI, io);
		out <<= 1;
		OUTB(IO_SPI, io | SPI_SCK);
		in <<= 1;
		INB(io, IO_SPI);
		in |= (io & SPI_SO);
	}
	OUTB(IO_SPI, 0);
	return (in >> SPI_SO_BITPOS);
}

