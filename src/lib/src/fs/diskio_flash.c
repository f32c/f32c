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
	.write	= flash_write,
	.ioctl	= flash_ioctl,
	.status	= flash_init_status,
	.init	= flash_init_status
};

struct flash_priv {
	uint32_t	io_port;
	uint16_t	offset;
	uint16_t	size;
	uint8_t		io_slave;
	uint8_t		jed_id[3];
};

#define DISKIO2PRIV(d)  ((struct flash_priv *)((void *)(d)->priv_data))

#define	FLASH_SECLEN	4096

#define	SPI_CMD_WRSR	0x01	/* Write Status & Configuration Register */
#define	SPI_CMD_PAGEWR	0x02	/* 256-byte "page" write */
#define	SPI_CMD_READ	0x03	/* Slow read (no gap byte after address) */
#define	SPI_CMD_WRDI	0x04	/* Write Disable */
#define	SPI_CMD_RDSR	0x05	/* Read Status Register */
#define	SPI_CMD_WREN	0x06	/* Write Enable */
#define	SPI_CMD_FASTRD	0x0B	/* Fast read (dummy byte after address) */
#define	SPI_CMD_ERSEC	0x20	/* 4 KB Sector erase */
#define	SPI_CMD_DOR	0x3B	/* Dual output read */
#define	SPI_CMD_ERSEC8	0x52	/* 8 KB Sector erase (not standard!)*/
#define	SPI_CMD_EWSR	0x50	/* Enable Write to Status Register */
#define	SPI_CMD_ERSEC32	0x52	/* 32 KB Sector erase (not standard!)*/
#define	SPI_CMD_BE	0x60	/* Bulk (chip) erase */
#define	SPI_CMD_QOR	0x6B	/* Quad output read */
#define	SPI_CMD_REMS	0x90	/* Vendor-specific RDID version */
#define	SPI_CMD_RDID	0x9F	/* Read JEDEC ID, standard */
#define	SPI_CMD_RDID2	0xAB	/* Vendor-specific RDID version */
#define	SPI_CMD_AAIWR	0xAD	/* Auto Address Increment Write */
#define	SPI_CMD_DORX	0xBB	/* Dual output read */
#define	SPI_CMD_ERSSC64	0xD8	/* 64 KB Sector erase */
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

	/* Get SPI chip ID */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_RDID);
	byte = spi_byte(IO_SPI_FLASH, 0);

	if (byte == 0 || byte == 0xff)
		return STA_NOINIT;
	if (priv->jed_id[0] != 0 && priv->jed_id[0] != byte)
		res = STA_NOINIT;
	priv->jed_id[0] = byte;
	priv->jed_id[1] = spi_byte(IO_SPI_FLASH, 0);
	priv->jed_id[2] = spi_byte(IO_SPI_FLASH, 0);
	return res;
}


static DRESULT
flash_read(diskio_t di,  BYTE* buf, LBA_t sector, UINT count)
{
	struct flash_priv *priv = DISKIO2PRIV(di);
	int addr;

	sector += priv->offset;
	addr = sector * FLASH_SECLEN;

	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_FASTRD);
	spi_byte(IO_SPI_FLASH, addr >> 16);
	spi_byte(IO_SPI_FLASH, addr >> 8);
	spi_byte(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, 0); /* dummy byte, ignored */
	spi_block_in(IO_SPI_FLASH, buf, count * FLASH_SECLEN);
	return (RES_OK);
}


#ifndef DISKIO_RO
static void
busy_wait()
{

	do {
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_RDSR);
	} while (spi_byte(IO_SPI_FLASH, SPI_CMD_RDSR) & 1);
}


static void
flash_erase_sectors(int start, int cnt)
{
	int addr, sum, i;

	#if USE_EWSR
	/* Enable Write Status Register */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_EWSR);
	#endif

	#if USE_WREN_BEFORE_WRSR
	/* Write enable */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
	#endif

	#if USE_WRSR
	/* Clear write-protect bits */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WRSR);
	spi_byte(IO_SPI_FLASH, 0);
	#endif

	addr = start * FLASH_SECLEN;
	for (; cnt > 0; cnt--, addr += FLASH_SECLEN) {
		/* Skip already blank sectors */
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_FASTRD);
		spi_byte(IO_SPI_FLASH, addr >> 16);
		spi_byte(IO_SPI_FLASH, addr >> 8);
		spi_byte(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, 0); /* dummy byte, ignored */
		for (i = 0, sum = 0xff; i < FLASH_SECLEN && sum == 0xff; i++)
			sum &= spi_byte(IO_SPI_FLASH, 0);
		if (sum == 0xff)
			continue;

		/* Write enable */
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_ERSEC);
		spi_byte(IO_SPI_FLASH, addr >> 16);
		spi_byte(IO_SPI_FLASH, addr >> 8);
		spi_byte(IO_SPI_FLASH, 0);
		busy_wait();
	}
}


static DRESULT
flash_write(diskio_t di, const BYTE *buf, LBA_t sector, UINT count)
{
	struct flash_priv *priv = DISKIO2PRIV(di);
	int mfg_id, addr, i, j;
	int in_aai = 0;

	sector += priv->offset;

	/* Erase sectors */
	flash_erase_sectors(sector, count);

	mfg_id = priv->jed_id[0];
	addr = sector * FLASH_SECLEN;
	for (; count > 0; count--)
		switch (mfg_id) {
		case SPI_MFR_MICROCHIP:
			/* Write enable */
			spi_start_transaction(IO_SPI_FLASH);
			spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);

			for (i = 0; i < FLASH_SECLEN; i += 2) {
				spi_start_transaction(IO_SPI_FLASH);
				spi_byte(IO_SPI_FLASH, SPI_CMD_AAIWR);
				if (!in_aai) {
					spi_byte(IO_SPI_FLASH, addr >> 16);
					spi_byte(IO_SPI_FLASH, addr >> 8);
					spi_byte(IO_SPI_FLASH, 0);
				}
				spi_byte(IO_SPI_FLASH, *buf++);
				spi_byte(IO_SPI_FLASH, *buf++);
				in_aai = 1;
				busy_wait();
			}
			break;
		default:
			for (i = 0; i < FLASH_SECLEN; i += 256, addr += 256) {
				/* Write enable */
				spi_start_transaction(IO_SPI_FLASH);
				spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);

				spi_start_transaction(IO_SPI_FLASH);
				spi_byte(IO_SPI_FLASH, SPI_CMD_PAGEWR);
				spi_byte(IO_SPI_FLASH, addr >> 16);
				spi_byte(IO_SPI_FLASH, addr >> 8);
				spi_byte(IO_SPI_FLASH, 0);
				for (j = 0; j < 256; j++)
					spi_byte(IO_SPI_FLASH, *buf++);
				busy_wait();
			}
			break;
		}

	/* Write disable */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WRDI);
	busy_wait();

	return (RES_OK);
}
#endif /* !DISKIO_RO */


static DRESULT
flash_ioctl(diskio_t di, BYTE cmd, void* buf)
{
	struct flash_priv *priv = DISKIO2PRIV(di);
	WORD *up = buf;

	switch (cmd) {
	case GET_SECTOR_SIZE:
		*up = FLASH_SECLEN;
		return (RES_OK);
#ifndef DISKIO_RO
	case GET_SECTOR_COUNT:
		*up = priv->size;
		return (RES_OK);
	case GET_BLOCK_SIZE:
		/* XXX why? */
		return (RES_ERROR);
#if 0 /* XXX REVISIT TRIM */
	case CTRL_ERASE_SECTOR:
		/* XXX add offset to up[0], up[1] */
		flash_erase_sectors(up[0], up[1] - up[0] + 1);
		return (RES_OK);
#endif /* XXX revisit TRIM */
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

	di->sw = &flash_sw;
	priv->io_port = io_port;
	priv->io_slave = io_slave;
	priv->offset = offset / FLASH_SECLEN;
	priv->size = size / FLASH_SECLEN;
	diskio_attach_generic(di);
}
