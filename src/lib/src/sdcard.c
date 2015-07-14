/*-
 * Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id$
 */

#include <dev/io.h>
#include <dev/sdcard.h>
#include <dev/spi.h>

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
	spi_start_transaction(IO_SPI_SDCARD);

	/* Preamble */
	spi_byte(IO_SPI_SDCARD, 0xff);

	/* Command */
	spi_byte(IO_SPI_SDCARD, cmd | 0x40);

	/* Argument */
	spi_byte(IO_SPI_SDCARD, arg >> 24);
	spi_byte(IO_SPI_SDCARD, arg >> 16);
	spi_byte(IO_SPI_SDCARD, arg >> 8);
	spi_byte(IO_SPI_SDCARD, arg);

	/* Hack: CRC hidden in command bits 15..8 */
	spi_byte(IO_SPI_SDCARD, cmd >> 8);
	
	/* Wait for a valid response byte, up to 8 cycles */
	for (i = 0; i < 8; i++) {
		res = spi_byte(IO_SPI_SDCARD, 0xff);
		if ((res & 0x80) == 0)
			break;
	}
	return (res);
};


/*
 * Reads a data block of n bytes from the card and stores it in a buffer
 * pointed to by the buf argument.  Returns 0 on success, -1 on failure.
 */
static int
sdcard_read_block(char *buf)
{
	int i;

	/* Wait for data start token */
	for (i = 0; spi_byte(IO_SPI_SDCARD, 0xff) != 0xfe; i++)
		if (i == 1 << 24)
			return (-1);

	/* Fetch data */
	spi_block_in(IO_SPI_SDCARD, buf, SD_BLOCKLEN);

	/* CRC - ignored */
	spi_byte(IO_SPI_SDCARD, 0xff);
	spi_byte(IO_SPI_SDCARD, 0xff);
	return (0);
}


/*
 * Writes a data block of n bytes from the card and stores it in a buffer
 * pointed to by the buf argument.  Returns 0 on success, -1 on failure.
 */
static int
sdcard_write_block(char *buf)
{
	int i;

	/* Send a dummy byte, just in case */
	spi_byte(IO_SPI_SDCARD, 0xff);

	/* Send data start token */
	spi_byte(IO_SPI_SDCARD, 0xfc);

	/* Send data block */
	for (i = 0; i < SD_BLOCKLEN; i++)
		spi_byte(IO_SPI_SDCARD, buf[i]);

	/* Send two dummy CRC bytes */
	spi_byte(IO_SPI_SDCARD, 0xff);
	spi_byte(IO_SPI_SDCARD, 0xff);

	/* Wait while sdcard busy */
	for (i = 0; spi_byte(IO_SPI_SDCARD, 0xff) != 0xff; i++)
		if (i == 1 << 24)
			return (-1);

	spi_byte(IO_SPI_SDCARD, 0xff);
	return (0);
}


int
sdcard_init(void)
{
	int i, res;

	/* Mark card as uninitialized */
	sdcard_addr_shift = -1;
	
	/* Terminate current transaction, if any */
	sdcard_cmd(SD_CMD_STOP_TRANSMISSION, 0);

	/* Clock in some dummy data in an attempt to wake up the card */
	for (i = 0; i < (1 << 16); i++)
		spi_byte(IO_SPI_SDCARD, 0xff);

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
	if (spi_byte(IO_SPI_SDCARD, 0xff) & (1 << 6))
		sdcard_addr_shift = 0;	/* block addressing */
	/* Flush the remaining response bytes */
	for (i = 0; i < 3; i++)
		spi_byte(IO_SPI_SDCARD, 0xff);
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

	if (sdcard_cmd(SD_CMD_READ_MULTI_BLOCK, sector << sdcard_addr_shift))
		goto error;
	for (; cnt > 0; cnt--) {
		if (sdcard_read_block((char *) buf))
			goto error;
		buf += SD_BLOCKLEN;
	}
	/* Send a dummy byte, just in case */
	spi_byte(IO_SPI_SDCARD, 0xff);
	sdcard_cmd(SD_CMD_STOP_TRANSMISSION, 0);
	/* Wait while sdcard busy */
	for (cnt = 0; spi_byte(IO_SPI_SDCARD, 0xff) != 0xff; cnt++)
		if (cnt == 1 << 24)
			return (-1);
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

	sdcard_cmd(SD_CMD_APP_CMD, 0);
	if (sdcard_cmd(SD_CMD_SET_WR_BLOCK_ERASE_COUNT, cnt))
		goto error;
	spi_byte(IO_SPI_SDCARD, 0xff);

	if (sdcard_cmd(SD_CMD_WRITE_MULTI_BLOCK, sector << sdcard_addr_shift))
		goto error;
	spi_byte(IO_SPI_SDCARD, 0xff);

	for (; cnt > 0; cnt--) {
		if (sdcard_write_block((char *) buf))
			goto error;
		buf += SD_BLOCKLEN;
	}

	/* Send stop transmission token */
	spi_byte(IO_SPI_SDCARD, 0xfb);

	/* Wait while sdcard busy */
	spi_byte(IO_SPI_SDCARD, 0xff);
	for (cnt = 0; spi_byte(IO_SPI_SDCARD, 0xff) != 0xff; cnt++)
		if (cnt == 1 << 24)
			return (-1);
	return (RES_OK);
error:
	/* Mark the card as dead */
	sdcard_addr_shift = -1;
	return (RES_ERROR);
}
