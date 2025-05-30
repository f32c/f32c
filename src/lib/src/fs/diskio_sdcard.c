/*-
 * Copyright (c) 2013-2024 Marko Zec
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
 */

#include <fatfs/ff.h>
#include <fatfs/diskio.h>

#include <dev/io.h>
#include <dev/spi.h>


static DRESULT sdcard_read(diskio_t, BYTE *, LBA_t, UINT);
static DRESULT sdcard_write(diskio_t, const BYTE *, LBA_t, UINT);
static DRESULT sdcard_ioctl(diskio_t, BYTE, void *);
static DSTATUS sdcard_status(diskio_t);
static DSTATUS sdcard_init(diskio_t);

static struct diskio_sw sdcard_sw = {
	.read	= sdcard_read,
#ifndef DISKIO_RO
	.write	= sdcard_write,
#endif
	.ioctl	= sdcard_ioctl,
	.status	= sdcard_status,
	.init	= sdcard_init
};

struct sdcard_priv {
	uint32_t	io_port;
	uint8_t		io_slave;
	uint8_t		flags;
	int8_t		addr_shift;
	int8_t		padding;
};

#define	SD_CMD_GO_IDLE_STATE		0
#define	SD_CMD_SEND_OP_COND		1
#define	SD_CMD_SEND_IF_COND		8
#define	SD_CMD_SEND_CSD			9
#define	SD_CMD_SEND_CID			10
#define	SD_CMD_STOP_TRANSMISSION	12
#define	SD_CMD_SET_BLOCKLEN		16
#define	SD_CMD_READ_BLOCK		17
#define	SD_CMD_READ_MULTI_BLOCK		18
#define	SD_CMD_WRITE_BLOCK		24
#define	SD_CMD_WRITE_MULTI_BLOCK	25
#define	SD_CMD_APP_CMD			55
#define	SD_CMD_READ_OCR			58

/* ACMD commands which require SD_CMD_APP_CMD prefix */
#define	SD_CMD_SET_WR_BLOCK_ERASE_COUNT	23
#define	SD_CMD_APP_SEND_OP_COND		41

#define	SDCARD_SECLEN	512


/*
 * Sends a command with a 32-bit argument to the card, and returns
 * a single byte received as a response from the card.
 */
static int
sdcard_cmd(struct sdcard_priv *priv, int cmd, uint32_t arg)
{
	int i, res;

	/* Init SPI */
	spi_start_transaction(priv->io_port);

	/* Preamble */
	spi_byte(priv->io_port, 0xff);

	/* Command */
	spi_byte(priv->io_port, cmd | 0x40);

	/* Argument */
	spi_byte(priv->io_port, arg >> 24);
	spi_byte(priv->io_port, arg >> 16);
	spi_byte(priv->io_port, arg >> 8);
	spi_byte(priv->io_port, arg);

	/* Hack: CRC hidden in command bits 15..8 */
	spi_byte(priv->io_port, cmd >> 8);

	/* Wait for a valid response byte, up to 8 cycles */
	for (i = 0; i < 8; i++) {
		res = spi_byte(priv->io_port, 0xff);
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
sdcard_read_block(struct sdcard_priv *priv, char *buf)
{
	int i;

	/* Wait for data start token */
	for (i = 0; spi_byte(priv->io_port, 0xff) != 0xfe; i++)
		if (i == 1 << 20) /* XXX revisit! */
			return (-1);

	/* Fetch data */
	spi_block_in(priv->io_port, buf, SDCARD_SECLEN);

	/* CRC - ignored */
	spi_byte(priv->io_port, 0xff);
	spi_byte(priv->io_port, 0xff);
	return (0);
}


/*
 * Writes a data block of n bytes from the card and stores it in a buffer
 * pointed to by the buf argument.  Returns 0 on success, -1 on failure.
 */
static int
sdcard_write_block(struct sdcard_priv *priv, char *buf)
{
	int i;

	/* Send a dummy byte, just in case */
	spi_byte(priv->io_port, 0xff);

	/* Send data start token */
	spi_byte(priv->io_port, 0xfc);

	/* Send data block */
	spi_block_out(priv->io_port, buf, SDCARD_SECLEN);

	/* Send two dummy CRC bytes */
	spi_byte(priv->io_port, 0xff);
	spi_byte(priv->io_port, 0xff);

	/* Wait while sdcard busy */
	for (i = 0; spi_byte(priv->io_port, 0xff) != 0xff; i++)
		if (i == 1 << 24)
			return (-1);

	spi_byte(priv->io_port, 0xff);
	return (0);
}


static int
sdcard_init_x(struct sdcard_priv *priv)
{
	int i, res;

	/* Mark card as uninitialized */
	priv->addr_shift = -1;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	/* Terminate current transaction, if any */
	sdcard_cmd(priv, SD_CMD_STOP_TRANSMISSION, 0);

	/* Clock in some dummy data in an attempt to wake up the card */
	for (i = 0; i < (1 << 16); i++)
		spi_byte(priv->io_port, 0xff);

	/* CRC embedded in bits 15..8 of command word */
	res = sdcard_cmd(priv, SD_CMD_GO_IDLE_STATE | 0x9500, 0) & 0xfe;
	if (res)
		return (res);

	/* CRC embedded in bits 15..8 of command word */
	res = sdcard_cmd(priv, SD_CMD_SEND_IF_COND | 0x8700, 0x01aa) & 0xfe;
	if (res)
		return (res);

	/* Initiate initialization process, loop until done */
	for (i = 0; i < (1 << 16); i++) {
		sdcard_cmd(priv, SD_CMD_APP_CMD, 0);
		res = sdcard_cmd(priv, SD_CMD_APP_SEND_OP_COND, 1 << 30);
		if (res == 0)
			break;
	}
	if (res)
		return (res);

	/* Default: byte addressing = block * 512 */
	priv->addr_shift = 9;

	/* Set block size to 512 */
	res = sdcard_cmd(priv, SD_CMD_SET_BLOCKLEN, SDCARD_SECLEN);
	if (res)
		return (res);

	/* READ_OCR: SD or SDHC? */
	if (sdcard_cmd(priv, SD_CMD_READ_OCR, 1 << 30))
		return (0);

	/* byte #1, bit 6 of response determines card type */
	if (spi_byte(priv->io_port, 0xff) & (1 << 6))
		priv->addr_shift = 0;	/* block addressing */
	/* Flush the remaining response bytes */
	for (i = 0; i < 3; i++)
		spi_byte(priv->io_port, 0xff);
	return (0);
}


static DSTATUS
sdcard_init(diskio_t di)
{
	struct sdcard_priv *priv = DISKIO2PRIV(di);

	if (sdcard_init_x(priv))
		return STA_NOINIT;
	else
		return 0;
}


DSTATUS
sdcard_status(diskio_t di)
{
	struct sdcard_priv *priv = DISKIO2PRIV(di);

	if (priv->addr_shift < 0)
		return STA_NOINIT;
	else
		return 0;
}


static DRESULT
sdcard_read(diskio_t di,  BYTE* buf, LBA_t sector, UINT cnt)
{
	struct sdcard_priv *priv = DISKIO2PRIV(di);

	if (priv->addr_shift < 0)
		goto error;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	if (sdcard_cmd(priv, SD_CMD_READ_MULTI_BLOCK,
	    sector << priv->addr_shift))
		goto error;
	for (; cnt > 0; cnt--) {
		if (sdcard_read_block(priv, (char *) buf))
			goto error;
		buf += SDCARD_SECLEN;
	}
	/* Send a dummy byte, just in case */
	spi_byte(priv->io_port, 0xff);
	sdcard_cmd(priv, SD_CMD_STOP_TRANSMISSION, 0);
	/* Wait while sdcard busy */
	for (cnt = 0; spi_byte(priv->io_port, 0xff) != 0xff; cnt++)
		if (cnt == 1 << 20) /* XXX revisit! */
			return (-1);
	return (RES_OK);
error:
	/* Mark the card as dead */
	priv->addr_shift = -1;
	return (RES_ERROR);
}


static DRESULT
sdcard_write(diskio_t di, const BYTE *buf, LBA_t sector, UINT cnt)
{
	struct sdcard_priv *priv = DISKIO2PRIV(di);

	if (priv->addr_shift < 0)
		goto error;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	sdcard_cmd(priv, SD_CMD_APP_CMD, 0);
	if (sdcard_cmd(priv, SD_CMD_SET_WR_BLOCK_ERASE_COUNT, cnt))
		goto error;
	spi_byte(priv->io_port, 0xff);

	if (sdcard_cmd(priv, SD_CMD_WRITE_MULTI_BLOCK,
	    sector << priv->addr_shift))
		goto error;
	spi_byte(priv->io_port, 0xff);

	for (; cnt > 0; cnt--) {
		if (sdcard_write_block(priv, (char *) buf))
			goto error;
		buf += SDCARD_SECLEN;
	}

	/* Send stop transmission token */
	spi_byte(priv->io_port, 0xfb);

	/* Wait while sdcard busy */
	spi_byte(priv->io_port, 0xff);
	for (cnt = 0; spi_byte(priv->io_port, 0xff) != 0xff; cnt++)
		if (cnt == 1 << 24)
			return (-1);
	return (RES_OK);
error:
	/* Mark the card as dead */
	priv->addr_shift = -1;
	return (RES_ERROR);
}


static DRESULT
sdcard_ioctl(diskio_t di, BYTE cmd, void* buf)
{
	WORD *sz = buf;

	switch (cmd) {
	case GET_SECTOR_SIZE:
		*sz = SDCARD_SECLEN;
		return (RES_OK);
	case CTRL_SYNC:
		return (RES_OK);
	default:
		return (RES_ERROR);
	}
}


void
diskio_attach_sdcard(diskio_t di, uint32_t io_port, uint8_t io_slave)
{
	struct sdcard_priv *priv = DISKIO2PRIV(di);

	di->d_sw = &sdcard_sw;
	di->d_mntfrom = diskio_devstr("SDcard@spi",
	    (io_port - IO_SPI_0) / (IO_SPI_1 - IO_SPI_0), io_slave, 0);
	priv->io_port = io_port;
	priv->io_slave = io_slave;
	priv->flags = 0;
	priv->addr_shift = -1;
	diskio_attach_generic(di);
}
