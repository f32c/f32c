
#include <io.h>
#include <spi.h>


int
spi_byte_in(int port)
{

	return (spi_byte(port, 0xff));
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
