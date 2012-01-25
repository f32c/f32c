
#include <types.h>
#include <spi.h>
#include <stdio.h>


int
sdcard_init(void)
{
	int i, j, k;

	/* Attempt to enter SPI mode */
	for (i = 0; i < 100; i++)
		spi_byte(SPI_PORT_SDCARD, 0xff);

	/* CMD 0 */
	spi_byte(SPI_PORT_SDCARD, 0x40);
	for (i = 0; i < 4; i++)
		spi_byte(SPI_PORT_SDCARD, 0x00);
	spi_byte(SPI_PORT_SDCARD, 0x95);
	spi_byte(SPI_PORT_SDCARD, 0xff);
	if (spi_byte(SPI_PORT_SDCARD, 0xff) != 1)
		return (-1);	/* Fail */

	for (j = 0; j < 100000; j++) {
		/* CMD 1 */
		spi_byte(SPI_PORT_SDCARD, 0x41);
		for (i = 0; i < 4; i++)
			spi_byte(SPI_PORT_SDCARD, 0x00);
		spi_byte(SPI_PORT_SDCARD, 0x95);
		spi_byte(SPI_PORT_SDCARD, 0xff);
		k = spi_byte(SPI_PORT_SDCARD, 0xff);
		spi_byte(SPI_PORT_SDCARD, 0xff);
		spi_byte(SPI_PORT_SDCARD, 0xff);
		if (k == 0)
			break;
	}

	return (k);
}
