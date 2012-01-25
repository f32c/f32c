
#include <types.h>
#include <spi.h>
#include <stdio.h>


static const char cmd0[] = {0x40, 0, 0, 0, 0, 0x95, 0xff, 0xff};
static const char cmd1[] = {0xff, 0xff, 0x41, 0, 0, 0, 0, 0x95, 0xff, 0xff};

int
sdcard_init(void)
{
	int i, j, byte;

	/* Attempt to enter SPI mode */
	for (i = 0; i < 100; i++)
		spi_byte(SPI_PORT_SDCARD, 0xff);

	for (i = 0; i < 8; i++)
		byte = spi_byte(SPI_PORT_SDCARD, cmd0[i]);
	if (byte != 1)
		return (-1);

	for (j = 0; j < 100000; j++) {
		for (i = 0; i < 10; i++)
			byte = spi_byte(SPI_PORT_SDCARD, cmd1[i]);
		if (byte == 0)
			break;
	}

	return (byte);
}
