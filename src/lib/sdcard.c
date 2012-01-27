
#include <types.h>
#include <sdcard.h>
#include <spi.h>


/*
 * Sends a command with a 32-bit argument to the card, and returns
 * a single byte received as a response from the card.
 */
int
sdcard_cmd(int cmd, uint32_t arg)
{
	int i, res;

	/* Preamble */
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


/*
 * Reads a data block of n bytes from the card and stores it in a buffer
 * pointed to by the buf argument.  Returns 0 on success, -1 on failure.
 */
int
sdcard_read(char *buf, int n)
{
	int i;

	/* Wait for data start token */
	for (i = 10000; spi_byte_in(SPI_PORT_SDCARD) != 0xfe; i--) {
		if (i == 0)
			return (-1);
	}

	/* Fetch data */
	for (; n > 0; n--)
		*buf++ = spi_byte_in(SPI_PORT_SDCARD);
        
	/* CRC - ignored */
	spi_byte_in(SPI_PORT_SDCARD);
	spi_byte_in(SPI_PORT_SDCARD);

	return (0);
}


int
sdcard_init(void)
{
	int i, res;

	res = sdcard_cmd(SDCARD_CMD_GO_IDLE_STATE, 0) ^ 0x01;
	if (res)
		return (res);

	/* Initiate initialization process, loop until done */
	for (i = 0; i < (1 << 16); i++) {
		res = sdcard_cmd(SDCARD_CMD_SEND_OP_COND, 0);
		if (res == 0)
			break;
	}

	return (res);
}
