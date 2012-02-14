
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

	/* Preamble */
	spi_byte_in(SPI_PORT_SDCARD);

	/* Command */
	spi_byte(SPI_PORT_SDCARD, cmd | 0x40);

	/* Argument */
	spi_byte(SPI_PORT_SDCARD, arg >> 24);
	spi_byte(SPI_PORT_SDCARD, arg >> 16);
	if (sio_idle_fn != NULL)
		(*sio_idle_fn)();
	spi_byte(SPI_PORT_SDCARD, arg >> 8);
	spi_byte(SPI_PORT_SDCARD, arg);

	/* Hack: CRC hidden in command bits 15..8 */
	spi_byte(SPI_PORT_SDCARD, cmd >> 8);
	
	/* Wait for a valid response byte, up to 8 cycles */
	for (i = 0; i < 8; i++) {
		res = spi_byte_in(SPI_PORT_SDCARD);
		if ((res & 0x80) == 0)
			break;
		if (sio_idle_fn != NULL)
			(*sio_idle_fn)();
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
	for (; n > 0; n--) {
		if (sio_idle_fn != NULL && (i & SD_IDLE_MASK) == 0)
			(*sio_idle_fn)();
		*buf++ = spi_byte_in(SPI_PORT_SDCARD);
	}
        
	/* CRC - ignored */
	spi_byte_in(SPI_PORT_SDCARD);
	spi_byte_in(SPI_PORT_SDCARD);

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
	for (i = 0; i < (1 << 16); i++) {
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


DSTATUS
disk_initialize(BYTE drive __unused)
{

	if (sdcard_init())
		return(STA_NOINIT);
	else
		return (0);
}


DSTATUS
disk_status(BYTE drive __unused)
{

	if (sdcard_addr_shift < 0)
		return(STA_NOINIT);
	else
		return (0);
}


DRESULT
disk_read (BYTE Drive __unused, BYTE* Buffer, DWORD SectorNumber,
    BYTE SectorCount)
{

	if (sdcard_addr_shift < 0)
		goto error;

	for (; SectorCount > 0; SectorCount--) {
		if (sdcard_cmd(SD_CMD_READ_BLOCK,
		    SectorNumber << sdcard_addr_shift))
			goto error;
		if (sdcard_read((char *) Buffer, SD_BLOCKLEN))
			goto error;
	}
	return (RES_OK);

error:
	/* Mark the card as dead */
	sdcard_addr_shift = -1;
	return(RES_ERROR);
}
