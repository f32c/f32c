
#include <io.h>
#include <spi.h>


__attribute__((optimize("-O3"))) 
void
spi_block_in(int port, void *buf, int len)
{
	char *cp = (char *) buf;
	int c, cnt;

	if (len == 0)
		return;

	SB(0xff, IO_SPI_FLASH, port);
	do {
		LW(c, IO_SPI_FLASH, port);
	} while ((c & 0x100) == 0);
	for (cnt = 1; cnt != len; cnt++) {
		SB(0xff, IO_SPI_FLASH, port);
		*cp++ = c;
		do {
			LW(c, IO_SPI_FLASH, port);
		} while ((c & 0x100) == 0);
	}
	*cp = c;
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
