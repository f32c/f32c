
#include <sys/param.h>
#include <mips/endian.h>
#include <io.h>


#if (SPI_SI != 0x80)
#error SPI_SI must be 0x80!
#endif
#if (SPI_SO_BITPOS != 0)
#error SPI_SO_BITPOS must be 0!
#endif


int
spi_byte_in(int port)
{
	int i, io, in = 0;

	for (i = 8; i > 0; i--) {
		SB(SPI_SCK | SPI_SI, IO_SPI_FLASH, port);
		in <<= 1;
#if _BYTE_ORDER == _LITTLE_ENDIAN
		LW(io, IO_SPI_FLASH, port);	/* Speed optimization */
#else
		LB(io, IO_SPI_FLASH, port);
#endif
		SB(SPI_SI, IO_SPI_FLASH, port);
		in |= io;
	}
	return (in);
}


int
spi_byte(int port, int out)
{
	int i, io, in = 0;

	for (i = 8; i > 0; i--) {
		io = out & SPI_SI;
		SB(io, IO_SPI_FLASH, port);
		out <<= 1;
		SB(io | SPI_SCK, IO_SPI_FLASH, port);
#if _BYTE_ORDER == _LITTLE_ENDIAN
		LW(io, IO_SPI_FLASH, port);	/* Speed optimization */
#else
		LB(io, IO_SPI_FLASH, port);
#endif
		in <<= 1;
		in |= io;
	}
	SB(SPI_SI, IO_SPI_FLASH, port);
	return (in);
}

