
#include <sys/param.h>

#include <io.h>
#include <spi.h>


#if (_BYTE_ORDER == _LITTLE_ENDIAN)
#define	SPI_READY_MASK (1 << 8)
#else
#define	SPI_READY_MASK (1 << 16)
#endif

void
spi_block_in(int port, void *buf, int len)
{
	uint32_t *wp = (uint32_t *) buf;
	uint32_t w = 0;
	uint32_t c;

	if (len == 0)
		return;

	SB(0xff, IO_SPI_FLASH, port);
	do {
		LW(c, IO_SPI_FLASH, port);
	} while ((c & SPI_READY_MASK) == 0);
	for (len--; len != 0; len--) {
		SB(0xff, IO_SPI_FLASH, port);
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
		w = (w >> 8) | (c << 24);
#else
		w = (w << 8) | (c >> 24);
#endif
		if ((len & 3) == 0)
			*wp++ = w;
		do {
			LW(c, IO_SPI_FLASH, port);
		} while ((c & SPI_READY_MASK) == 0);
	}
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
	w = (w >> 8) | (c << 24);
#else
	w = (w << 8) | (c >> 24);
#endif
	*wp++ = w;
}


int
spi_byte(int port, int out)
{
	uint32_t in;

	SB(out, IO_SPI_FLASH, port);
	do {
		LW(in, IO_SPI_FLASH, port);
	} while ((in & SPI_READY_MASK) == 0);
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
	return (in & 0xff);
#else
	return (in >> 24);
#endif
}


void
spi_start_transaction(int port)
{
	uint32_t in;

	SB(0x80, IO_SPI_FLASH, port + 1);
	do {
		LW(in, IO_SPI_FLASH, port + 1);
	} while ((in & SPI_READY_MASK) == 0);
}
