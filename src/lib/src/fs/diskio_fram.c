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


static DRESULT fram_read(diskio_t, BYTE *, LBA_t, UINT);
static DRESULT fram_write(diskio_t, const BYTE *, LBA_t, UINT);
static DRESULT fram_ioctl(diskio_t, BYTE, void *);
static DSTATUS fram_init_status(diskio_t);

static struct diskio_sw fram_sw = {
	.read	= fram_read,
	.write	= fram_write,
	.ioctl	= fram_ioctl,
	.status	= fram_init_status,
	.init	= fram_init_status
};

struct fram_priv {
	uint32_t	io_port;
	uint16_t	offset;
	uint16_t	size;
	uint8_t		io_slave;
	uint8_t		flags;
	uint8_t		padding[2];
};

#define DISKIO2PRIV(d)  ((struct fram_priv *)((void *)(d)->priv_data))

#define	FRAM_SECLEN	512

#define	FRAM_CMD_WRITE	0x02
#define	FRAM_CMD_WRDI	0x04
#define	FRAM_CMD_WREN	0x06
#define	FRAM_CMD_FSTRD	0x0b

#define	F_WREN_DONE	1


static DSTATUS
fram_init_status(diskio_t di)
{

	return 0;
}


static DRESULT
fram_read(diskio_t di,  BYTE* buf, LBA_t sector, UINT count)
{
	struct fram_priv *priv = DISKIO2PRIV(di);
	int addr;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	sector += priv->offset;
	addr = sector * FRAM_SECLEN;

	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, FRAM_CMD_FSTRD);
	spi_byte(priv->io_port, addr >> 16);
	spi_byte(priv->io_port, addr >> 8);
	spi_byte(priv->io_port, 0);
	spi_byte(priv->io_port, 0); /* dummy byte, ignored */
	spi_block_in(priv->io_port, buf, count * FRAM_SECLEN);
	return (RES_OK);
}


#ifndef DISKIO_RO
static DRESULT
fram_write(diskio_t di, const BYTE *buf, LBA_t sector, UINT count)
{
	struct fram_priv *priv = DISKIO2PRIV(di);
	int addr;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	sector += priv->offset;
	addr = sector * FRAM_SECLEN;

	if ((priv->flags & F_WREN_DONE) == 0) {
		spi_start_transaction(priv->io_port);
		spi_byte(priv->io_port, FRAM_CMD_WREN);
		priv->flags |= F_WREN_DONE;
	}
	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, FRAM_CMD_WRITE);
	spi_byte(priv->io_port, addr >> 16);
	spi_byte(priv->io_port, addr >> 8);
	spi_byte(priv->io_port, 0);
	spi_block_out(priv->io_port, buf, count * FRAM_SECLEN);
	return (RES_OK);
}
#endif


static DRESULT
fram_ioctl(diskio_t di, BYTE cmd, void* buf)
{
	struct fram_priv *priv = DISKIO2PRIV(di);
	LBA_t *sec = buf;
	WORD *sz = buf;

	switch (cmd) {
	case GET_SECTOR_SIZE:
		*sz = FRAM_SECLEN;
		return (RES_OK);
#ifndef DISKIO_RO
	case GET_SECTOR_COUNT:
		*sec = priv->size;
		return (RES_OK);
	case GET_BLOCK_SIZE:
		*sz = 1;
		return (RES_OK);
#endif /* !DISKIO_RO */
	case CTRL_SYNC:
		return (RES_OK);
	default:
		return (RES_ERROR);
	}
}


void
diskio_attach_fram(diskio_t di, uint32_t io_port, uint8_t io_slave,
    uint32_t offset, uint32_t size)
{
	struct fram_priv *priv = DISKIO2PRIV(di);

	di->sw = &fram_sw;
	priv->io_port = io_port;
	priv->io_slave = io_slave;
	priv->offset = offset / FRAM_SECLEN;
	priv->size = size / FRAM_SECLEN;
	priv->flags = 0;
	diskio_attach_generic(di);
}
