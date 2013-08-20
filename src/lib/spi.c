
#include <sys/param.h>

#include <io.h>
#include <spi.h>


void
spi_block_in(int port, void *buf, int len)
{
	uint32_t *wp = (uint32_t *) buf;
	uint32_t w = 0;
	int c;

	if (len == 0)
		return;

	SB(0xff, IO_SPI_FLASH, port);
	do {
		LW(c, IO_SPI_FLASH, port);
	} while ((c & 0x100) == 0);
	for (len--; len != 0; len--) {
		SB(0xff, IO_SPI_FLASH, port);
		w = (w >> 8) | (c << 24);
		if ((len & 3) == 0)
			*wp++ = w;
		do {
			LW(c, IO_SPI_FLASH, port);
		} while ((c & 0x100) == 0);
	}
	w = (w >> 8) | (c << 24);
	*wp++ = w;
}


int
spi_byte(int port, int out)
{
	int in;

	SB(out, IO_SPI_FLASH, port);
	do {
		LW(in, IO_SPI_FLASH, port);
	} while ((in & 0x100) == 0);
	return (in & 0xff);
}


void
spi_start_transaction(int port)
{
	int in;

	SB(0x80, IO_SPI_FLASH, port + 1);
	do {
		LW(in, IO_SPI_FLASH, port + 1);
	} while ((in & 0x100) == 0);
}
