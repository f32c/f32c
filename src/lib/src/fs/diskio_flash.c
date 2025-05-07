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

#include <stdio.h>

#include <fatfs/ff.h>
#include <fatfs/diskio.h>

#include <dev/io.h>
#include <dev/spi.h>


static DRESULT flash_read(diskio_t, BYTE *, LBA_t, UINT);
static DRESULT flash_write(diskio_t, const BYTE *, LBA_t, UINT);
static DRESULT flash_ioctl(diskio_t, BYTE, void *);
static DSTATUS flash_init_status(diskio_t);

static struct diskio_sw flash_sw = {
	.read	= flash_read,
#ifndef DISKIO_RO
	.write	= flash_write,
#endif
	.ioctl	= flash_ioctl,
	.status	= flash_init_status,
	.init	= flash_init_status
};

struct flash_priv {
	uint32_t	io_port;
	uint16_t	offset;
	uint16_t	size;
	uint8_t		io_slave;
	uint8_t		flags;
	uint8_t		jed_id[3];
	uint8_t		padding[3];
};

#define	F_BER32K	(1 << 0)
#define	F_BER32K_BROKEN	(1 << 1)
#define	F_BER64K	(1 << 2)
#define	F_BER64K_BROKEN	(1 << 3)
#define	F_UNLOCK_DONE	(1 << 4)

#define	FLASH_SECLEN	4096

#define	SPI_CMD_WRSR	0x01	/* Write Status & Configuration Register */
#define	SPI_CMD_PAGEWR	0x02	/* 256-byte "page" write */
#define	SPI_CMD_READ	0x03	/* Slow read (no gap byte after address) */
#define	SPI_CMD_WRDI	0x04	/* Write Disable */
#define	SPI_CMD_RDSR	0x05	/* Read Status Register */
#define	SPI_CMD_WREN	0x06	/* Write Enable */
#define	SPI_CMD_FASTRD	0x0B	/* Fast read (dummy byte after address) */
#define	SPI_CMD_SER	0x20	/* 4 KB Sector erase (standard) */
#define	SPI_CMD_DOR	0x3B	/* Dual output read */
#define	SPI_CMD_EWSR	0x50	/* Enable Write to Status Register */
#define	SPI_CMD_BER32K	0x52	/* 32 KB block erase (fairly standard)*/
#define	SPI_CMD_BE	0x60	/* Bulk (chip) erase (standard) */
#define	SPI_CMD_QOR	0x6B	/* Quad output read */
#define	SPI_CMD_REMS	0x90	/* Vendor-specific RDID version */
#define	SPI_CMD_RDID	0x9F	/* Read JEDEC ID (standard) */
#define	SPI_CMD_RDID2	0xAB	/* Vendor-specific RDID version */
#define	SPI_CMD_AAIWR	0xAD	/* Auto Address Increment Write (not std!) */
#define	SPI_CMD_DORX	0xBB	/* Dual output read */
#define	SPI_CMD_BER64K	0xD8	/* 64 KB block erase (mostly standard) */
#define	SPI_CMD_QORX	0xEB	/* Quad output read */

#define	SPI_MFR_CYPRESS		0x01
#define	SPI_MFR_FUJITSU		0x04
#define	SPI_MFR_ONSEMI		0x62
#define	SPI_MFR_PUYA		0x85
#define	SPI_MFR_ISSI		0x9d
#define	SPI_MFR_MICROCHIP	0xbf
#define	SPI_MFR_MACRONIX	0xc2
#define	SPI_MFR_WINBOND		0xef

#define	USE_EWSR 		1
#define	USE_WREN_BEFORE_WRSR	1
#define	USE_WRSR 		1


static DSTATUS
flash_init_status(diskio_t di)
{
	struct flash_priv *priv = DISKIO2PRIV(di);
	uint32_t byte;
	DSTATUS res = 0;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	/* Get SPI chip ID */
	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, SPI_CMD_RDID);
	byte = spi_byte(priv->io_port, 0);

	if (byte == 0 || byte == 0xff)
		return STA_NOINIT;
	if (priv->jed_id[0] != 0 && priv->jed_id[0] != byte)
		res = STA_NOINIT;
	priv->jed_id[0] = byte;
	priv->jed_id[1] = spi_byte(priv->io_port, 0);
	priv->jed_id[2] = spi_byte(priv->io_port, 0);

#ifndef DISKIO_RO
	if (res || (priv->flags & F_UNLOCK_DONE))
		return res;

	#if USE_EWSR
	/* Enable Write Status Register */
	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, SPI_CMD_EWSR);
	#endif

	#if USE_WREN_BEFORE_WRSR
	/* Write enable */
	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, SPI_CMD_WREN);
	#endif

	#if USE_WRSR
	/* Clear write-protect bits */
	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, SPI_CMD_WRSR);
	spi_byte(priv->io_port, 0);
	#endif

	priv->flags |= F_UNLOCK_DONE;
#endif
	return res;
}


static DRESULT
flash_read(diskio_t di,  BYTE* buf, LBA_t sector, UINT count)
{
	struct flash_priv *priv = DISKIO2PRIV(di);
	int addr;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	sector += priv->offset;
	addr = sector * FLASH_SECLEN;

	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, SPI_CMD_FASTRD);
	spi_byte(priv->io_port, addr >> 16);
	spi_byte(priv->io_port, addr >> 8);
	spi_byte(priv->io_port, 0);
	spi_byte(priv->io_port, 0); /* dummy byte, ignored */
	spi_block_in(priv->io_port, buf, count * FLASH_SECLEN);
	return (RES_OK);
}


#ifndef DISKIO_RO
static void
busy_wait(struct flash_priv *priv)
{

	do {
		spi_start_transaction(priv->io_port);
		spi_byte(priv->io_port, SPI_CMD_RDSR);
	} while (spi_byte(priv->io_port, SPI_CMD_RDSR) & 1);
}


static int
blank_check(struct flash_priv *priv, int addr, int len)
{

	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, SPI_CMD_FASTRD);
	spi_byte(priv->io_port, addr >> 16);
	spi_byte(priv->io_port, addr >> 8);
	spi_byte(priv->io_port, 0);
	spi_byte(priv->io_port, 0); /* dummy byte, ignored */
	for (; len != 0; len--)
		if (spi_byte(priv->io_port, 0) != 0xff)
			return 0;
	return 1;
}


static void
flash_erase_sectors(struct flash_priv *priv, int start, int cnt)
{
	int addr, step, flags;

	addr = start * FLASH_SECLEN;
	for (; cnt > 0; cnt -= step, addr += step * FLASH_SECLEN) {
retry:
		flags = 0;
		step = 1;
		/* Skip already blank sectors */
		if (blank_check(priv, addr, FLASH_SECLEN))
			continue;

		/* Write enable */
		spi_start_transaction(priv->io_port);
		spi_byte(priv->io_port, SPI_CMD_WREN);
		spi_start_transaction(priv->io_port);
		if (!(priv->flags & F_BER64K_BROKEN)
		    && (addr & 0xffff) == 0 && cnt >= 16) {
			spi_byte(priv->io_port, SPI_CMD_BER64K);
			flags = F_BER64K;
			step = 16;
		} else if (!(priv->flags & F_BER32K_BROKEN)
		    && (addr & 0x7fff) == 0 && cnt >= 8) {
			spi_byte(priv->io_port, SPI_CMD_BER32K);
			flags = F_BER32K;
			step = 8;
		} else
			spi_byte(priv->io_port, SPI_CMD_SER);
		spi_byte(priv->io_port, addr >> 16);
		spi_byte(priv->io_port, addr >> 8);
		spi_byte(priv->io_port, 0);
		busy_wait(priv);
		if (flags == 0 || (flags & priv->flags) != 0)
			continue;

		/* Check whether the 32K / 64K block erase works */
		if (blank_check(priv, addr, step * FLASH_SECLEN)) {
			priv->flags |= flags;
			continue;
		}

		/* Mark the block erase method as BROKEN, retry standard */
		priv->flags |= flags << 1;
		goto retry;
	}
}


static DRESULT
flash_write(diskio_t di, const BYTE *buf, LBA_t sector, UINT count)
{
	struct flash_priv *priv = DISKIO2PRIV(di);
	int mfg_id, addr, i;
	int in_aai = 0;

	/* Slave select */
	spi_slave_select(priv->io_port, priv->io_slave);

	sector += priv->offset;

	/* Erase sectors */
	flash_erase_sectors(priv, sector, count);

	mfg_id = priv->jed_id[0];
	addr = sector * FLASH_SECLEN;
	for (; count > 0; count--)
		switch (mfg_id) {
		case SPI_MFR_MICROCHIP:
			/* Write enable */
			spi_start_transaction(priv->io_port);
			spi_byte(priv->io_port, SPI_CMD_WREN);

			for (i = 0; i < FLASH_SECLEN; i += 2) {
				spi_start_transaction(priv->io_port);
				spi_byte(priv->io_port, SPI_CMD_AAIWR);
				if (!in_aai) {
					spi_byte(priv->io_port, addr >> 16);
					spi_byte(priv->io_port, addr >> 8);
					spi_byte(priv->io_port, 0);
				}
				spi_byte(priv->io_port, *buf++);
				spi_byte(priv->io_port, *buf++);
				in_aai = 1;
				busy_wait(priv);
			}
			break;
		default:
			for (i = 0; i < FLASH_SECLEN; i += 256, addr += 256) {
				/* Write enable */
				spi_start_transaction(priv->io_port);
				spi_byte(priv->io_port, SPI_CMD_WREN);

				spi_start_transaction(priv->io_port);
				spi_byte(priv->io_port, SPI_CMD_PAGEWR);
				spi_byte(priv->io_port, addr >> 16);
				spi_byte(priv->io_port, addr >> 8);
				spi_byte(priv->io_port, 0);
				spi_block_out(priv->io_port, buf, 256);
				buf += 256;
				busy_wait(priv);
			}
			break;
		}

	/* Write disable */
	spi_start_transaction(priv->io_port);
	spi_byte(priv->io_port, SPI_CMD_WRDI);
	busy_wait(priv);

	return (RES_OK);
}
#endif /* !DISKIO_RO */


static DRESULT
flash_ioctl(diskio_t di, BYTE cmd, void* buf)
{
	struct flash_priv *priv = DISKIO2PRIV(di);
	LBA_t *sec = buf;
	WORD *sz = buf;

	switch (cmd) {
	case GET_SECTOR_SIZE:
		*sz = FLASH_SECLEN;
		return (RES_OK);
#ifndef DISKIO_RO
	case GET_SECTOR_COUNT:
		*sec = priv->size;
		return (RES_OK);
	case GET_BLOCK_SIZE:
		*sz = 1;
		return (RES_OK);
	case CTRL_TRIM:
		spi_slave_select(priv->io_port, priv->io_slave);
		flash_erase_sectors(priv, sec[0] + priv->offset,
		    sec[1] - sec[0] + 1);
		return (RES_OK);
#endif /* !DISKIO_RO */
	case CTRL_SYNC:
		return (RES_OK);
	default:
		return (RES_ERROR);
	}
}


void
diskio_attach_flash(diskio_t di, uint32_t io_port, uint8_t io_slave,
    uint32_t offset, uint32_t size)
{
	struct flash_priv *priv = DISKIO2PRIV(di);

	di->d_sw = &flash_sw;
	priv->io_port = io_port;
	priv->io_slave = io_slave;
	priv->offset = offset / FLASH_SECLEN;
	priv->size = size / FLASH_SECLEN;
	priv->flags = 0;
	diskio_attach_generic(di);
}
