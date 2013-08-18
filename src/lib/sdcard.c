
#include <sys/param.h>
#include <sdcard.h>
#include <spi.h>
#include <sio.h>

#include <fatfs/diskio.h>


#define	SD_IDLE_MASK 		0x00


static int sdcard_addr_shift;	


/*
 * Sends a command with a 32-bit argument to the card, and returns
 * a single byte received as a response from the card.
 */
int
sdcard_cmd(int cmd, uint32_t arg)
{
	int i, res;

	/* Init SPI */
	spi_start_transaction(SPI_PORT_SDCARD);

	/* Preamble */
	spi_byte_in(SPI_PORT_SDCARD);

	/* Command */
	spi_byte(SPI_PORT_SDCARD, cmd | 0x40);

	/* Argument */
	spi_byte(SPI_PORT_SDCARD, arg >> 24);
	spi_byte(SPI_PORT_SDCARD, arg >> 16);
	spi_byte(SPI_PORT_SDCARD, arg >> 8);
	spi_byte(SPI_PORT_SDCARD, arg);

	/* Hack: CRC hidden in command bits 15..8 */
	spi_byte(SPI_PORT_SDCARD, cmd >> 8);
	
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
		if (sio_idle_fn != NULL && (i & SD_IDLE_MASK) == 0)
			(*sio_idle_fn)();
		if (i == 0)
			return (-1);
	}

	/* Fetch data */
	spi_block_in(SPI_PORT_SDCARD, buf, n);
        
	/* CRC - ignored */
	spi_byte_in(SPI_PORT_SDCARD);
	spi_byte_in(SPI_PORT_SDCARD);

	return (0);
}


/*
 * Writes a data block of n bytes from the card and stores it in a buffer
 * pointed to by the buf argument.  Returns 0 on success, -1 on failure.
 */
int
sdcard_write(char *buf, int n)
{
	int i;

	/* Dummy byte */
	spi_byte_out(SPI_PORT_SDCARD, 0xff);

	/* Send data start token */
	spi_byte_out(SPI_PORT_SDCARD, 0xfe);

	/* Send data */
	for (i = 0; i < n; i++)
		spi_byte_out(SPI_PORT_SDCARD, buf[i]);
        
	/* Send two dummy CRC bytes */
	spi_byte_out(SPI_PORT_SDCARD, 0xff);
	spi_byte_out(SPI_PORT_SDCARD, 0xff);

	/* Get response */
	int res = spi_byte(SPI_PORT_SDCARD, 0xff);
//printf("sdcard_write() respones is %02x ", res & 0xff);

	/* Wait while SPI busy */
	for (i = 5000000; spi_byte(SPI_PORT_SDCARD, 0xff) != 0xff; i--) {
		if (i == 0)
			return (-1);
	}
//printf("%d\n", i);

	spi_byte_out(SPI_PORT_SDCARD, 0xff);

	return (0);
}


int
sdcard_init(void)
{
	int i, res;

	/* Mark card as uninitialized */
	sdcard_addr_shift = -1;
	
	/* CRC embedded in bits 15..8 of command word */
	res = sdcard_cmd(SD_CMD_GO_IDLE_STATE | 0x9500, 0) & 0xfe;
	if (res)
		return (res);

	/* CRC embedded in bits 15..8 of command word */
	res = sdcard_cmd(SD_CMD_SEND_IF_COND | 0x8700, 0x01aa) & 0xfe;
	if (res)
		return (res);

	/* Initiate initialization process, loop until done */
	for (i = 0; i < (1 << 18); i++) {
		sdcard_cmd(SD_CMD_APP_CMD, 0);
		res = sdcard_cmd(SD_CMD_APP_SEND_OP_COND, 1 << 30);
		if (res == 0)
			break;
	}
	if (res)
		return (res);

	/* Default: byte addressing = block * 512 */
	sdcard_addr_shift = 9;

	/* Set block size to 512 */
	res = sdcard_cmd(SD_CMD_SET_BLOCKLEN, SD_BLOCKLEN);
	if (res)
		return (res);

	/* READ_OCR: SD or SDHC? */
	if (sdcard_cmd(SD_CMD_READ_OCR, 1 << 30))
		return (0);

	/* byte #1, bit 6 of response determines card type */
	if (spi_byte_in(SPI_PORT_SDCARD) & (1 << 6))
		sdcard_addr_shift = 0;	/* block addressing */
	/* Flush the remaining response bytes */
	for (i = 0; i < 3; i++)
		spi_byte_in(SPI_PORT_SDCARD);

	return (0);
}


int
sdcard_disk_initialize(void)
{

	if (sdcard_init())
		return (STA_NOINIT);
	else
		return (0);
}


int
sdcard_disk_status(void)
{

	if (sdcard_addr_shift < 0)
		return (STA_NOINIT);
	else
		return (0);
}


int
sdcard_disk_read(uint8_t *buf, uint32_t sector, uint32_t cnt)
{

	if (sdcard_addr_shift < 0)
		goto error;

	for (; cnt > 0; cnt--) {
		if (sdcard_cmd(SD_CMD_READ_BLOCK, sector << sdcard_addr_shift))
			goto error;
		if (sdcard_read((char *) buf, SD_BLOCKLEN))
			goto error;
		buf += SD_BLOCKLEN;
		sector++;
	}
	return (RES_OK);

error:
	/* Mark the card as dead */
	sdcard_addr_shift = -1;
	return (RES_ERROR);
}


int
sdcard_disk_write(uint8_t *buf, uint32_t sector, uint32_t cnt)
{

	if (sdcard_addr_shift < 0)
		goto error;

	for (; cnt > 0; cnt--) {
		if (sdcard_cmd(SD_CMD_WRITE_BLOCK, sector << sdcard_addr_shift))
			goto error;
		if (sdcard_write((char *) buf, SD_BLOCKLEN))
			goto error;
		buf += SD_BLOCKLEN;
		sector++;
	}
	return (RES_OK);

error:
	/* Mark the card as dead */
	sdcard_addr_shift = -1;
	return (RES_ERROR);
}
