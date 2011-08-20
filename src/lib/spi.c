
#include <io.h>
#include <types.h>


#if (SPI_SI != 0x80)
#error SPI_SI must be 0x80!
#endif
#if (SPI_SO_BITPOS != 0)
#error SPI_SO_BITPOS must be 0!
#endif


int
spi_byte_in(void)
{
	int i, io, in = 0;

	for (i = 8; i > 0; i--) {
		OUTB(IO_SPI, SPI_SCK);
		in <<= 1;
#if _BYTE_ORDER == _LITTLE_ENDIAN
		INW(io, IO_SPI);	/* Speed optimization */
#else
		INB(io, IO_SPI);
#endif
		OUTB(IO_SPI, 0);
		in |= io;
	}
	return (in);
}


int
spi_byte(int out)
{
	int i, io, in = 0;

	for (i = 8; i > 0; i--) {
		io = out & SPI_SI;
		OUTB(IO_SPI, io);
		out <<= 1;
		OUTB(IO_SPI, io | SPI_SCK);
#if _BYTE_ORDER == _LITTLE_ENDIAN
		INW(io, IO_SPI);	/* Speed optimization */
#else
		INB(io, IO_SPI);
#endif
		in <<= 1;
		in |= io;
	}
	OUTB(IO_SPI, 0);
	return (in);
}

