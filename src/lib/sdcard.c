
#include <types.h>
#include <spi.h>


int
sdcard_cmd(int cmd, uint32_t arg)
{
	int i, res;

	/* Hold MOSI signal high for a few cycles */
	spi_byte_in(SPI_PORT_SDCARD);

	/* Command */
	spi_byte(SPI_PORT_SDCARD, cmd | 0x40);

	/* Argument */
	spi_byte(SPI_PORT_SDCARD, arg >> 24);
	spi_byte(SPI_PORT_SDCARD, arg >> 16);
	spi_byte(SPI_PORT_SDCARD, arg >> 8);
	spi_byte(SPI_PORT_SDCARD, arg);

	/* CRC, hardcoded for CMD 0 */
	spi_byte(SPI_PORT_SDCARD, 0x95);
	
	/* Wait for a valid response byte, up to 8 cycles */
	for (i = 0; i < 8; i++) {
		res = spi_byte_in(SPI_PORT_SDCARD);
		if ((res & 0x80) == 0)
			break;
	}

	return (res);
};


int
sdcard_idle(void)
{

	/* Preamble for entering SPI mode */
	sdcard_cmd(0xff, 0xffffffff);

	/* Enter idle mode */
	return(sdcard_cmd(0, 0) - 1);
}


int
sdcard_init(void)
{
	int i, res;

	res = sdcard_idle();
	if (res)
		return (res);

	/* Initiate initialization process, loop until done */
	for (i = 0; i < (1 << 16); i++) {
		res = sdcard_cmd(1, 0);
		if (res == 0)
			break;
	}

	return (res);
}
