/*-
 * Copyright (c) 2013, 2014 Marko Zec
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


#define	FLASH_BLOCKLEN	4096

#define	SPI_CMD_WRSR	0x01
#define	SPI_CMD_PAGEWR	0x02
#define	SPI_CMD_WRDI	0x04
#define	SPI_CMD_RDSR	0x05
#define	SPI_CMD_WREN	0x06
#define	SPI_CMD_FASTRD	0x0b
#define	SPI_CMD_ERSEC	0x20
#define	SPI_CMD_EWSR	0x50
#define	SPI_CMD_RDID	0x9F
#define	SPI_CMD_RDID2	0xAB
#define	SPI_CMD_AAIWR	0xAD

#define	SPI_MFG_CYPRESS	0x01
#define	SPI_MFG_ISSI1	0x15
#define	SPI_MFG_SPANS	0x16
#define	SPI_MFG_ISSI2	0x17
#define	SPI_MFG_SST	0xBF

#define	USE_EWSR 	0
#define	USE_WREN_BEFORE_WRSR 0
#define	USE_WRSR 	0


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

	addr = start * (FLASH_BLOCKLEN / 256);
	for (; cnt > 0; cnt--, addr += (FLASH_BLOCKLEN / 256)) {
		/* Skip already blank sectors */
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_FASTRD);
		spi_byte(IO_SPI_FLASH, addr >> 8);
		spi_byte(IO_SPI_FLASH, addr);
		spi_byte(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, 0); /* dummy byte, ignored */
		for (i = 0, sum = 0xff; i < FLASH_BLOCKLEN; i++)
			sum &= spi_byte(IO_SPI_FLASH, 0);
		if (sum == 0xff)
			continue;

		/* Write enable */
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_ERSEC);
		spi_byte(IO_SPI_FLASH, addr >> 8);
		spi_byte(IO_SPI_FLASH, addr);
		spi_byte(IO_SPI_FLASH, 0);
		busy_wait();
	}
}
#endif


DSTATUS
flash_init_status(diskio_t di)
{

	return (RES_OK);
}


#ifndef DISKIO_RO
static DRESULT
flash_write(diskio_t di, const BYTE *buf, LBA_t sector, UINT count)
{
	int mfg_id, addr, i, j, in_aai = 0;

printf("%s() %d\n", __FUNCTION__, __LINE__);
	/* Get SPI chip ID */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_RDID);
	mfg_id = spi_byte(IO_SPI_FLASH, 0);
	if (mfg_id == 0xff) {
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_RDID2);
		spi_byte(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, 0);
		mfg_id = spi_byte(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, 0);
	}

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

	/* Erase sectors */
	flash_erase_sectors(sector, count);

	addr = sector * (FLASH_BLOCKLEN / 256);
	for (; count > 0; count--)
		switch (mfg_id) {
		case SPI_MFG_SST:
			/* Write enable */
			spi_start_transaction(IO_SPI_FLASH);
			spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);

			for (i = 0; i < FLASH_BLOCKLEN; i += 2) {
				spi_start_transaction(IO_SPI_FLASH);
				spi_byte(IO_SPI_FLASH, SPI_CMD_AAIWR);
				if (!in_aai) {
					spi_byte(IO_SPI_FLASH, addr >> 8);
					spi_byte(IO_SPI_FLASH, addr);
					spi_byte(IO_SPI_FLASH, 0);
				}
				in_aai = 1;
				spi_byte(IO_SPI_FLASH, *buf++);
				spi_byte(IO_SPI_FLASH, *buf++);
				busy_wait();
			}
			/* XXX addr += ??? */
			break;
		case SPI_MFG_CYPRESS:
		case SPI_MFG_ISSI1:
		case SPI_MFG_ISSI2:
		case SPI_MFG_SPANS:
			for (i = 0; i < FLASH_BLOCKLEN; i += 256, addr++) {
				/* Write enable */
				spi_start_transaction(IO_SPI_FLASH);
				spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);

				spi_start_transaction(IO_SPI_FLASH);
				spi_byte(IO_SPI_FLASH, SPI_CMD_PAGEWR);
				spi_byte(IO_SPI_FLASH, addr >> 8);
				spi_byte(IO_SPI_FLASH, addr);
				spi_byte(IO_SPI_FLASH, 0);
				for (j = 0; j < 256; j++)
					spi_byte(IO_SPI_FLASH, *buf++);
				busy_wait();
			}
			break;
		default:
			return (RES_ERROR);
		}

	/* Write disable */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WRDI);
	busy_wait();

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
	/* Set write-protect bits */
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WRSR);
	spi_byte(IO_SPI_FLASH, 0x1c);
	#endif

	return (RES_OK);
}
#endif /* !DISKIO_RO */


DRESULT
flash_read(diskio_t di,  BYTE* buf, LBA_t sector, UINT count)
{
	int addr = sector * (FLASH_BLOCKLEN / 256);

printf("%s() %d\n", __FUNCTION__, __LINE__);
	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, SPI_CMD_FASTRD);
	spi_byte(IO_SPI_FLASH, addr >> 8);
	spi_byte(IO_SPI_FLASH, addr);
	spi_byte(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, 0); /* dummy byte, ignored */
	spi_block_in(IO_SPI_FLASH, buf, count * FLASH_BLOCKLEN);
	return (RES_OK);
}


DRESULT
flash_ioctl(diskio_t di, BYTE cmd, void* buf)
{
	WORD *up = buf;

printf("%s() %d\n", __FUNCTION__, __LINE__);
	switch (cmd) {
	case GET_SECTOR_SIZE:
		*up = FLASH_BLOCKLEN;
		return (RES_OK);
#ifndef DISKIO_RO
	case GET_SECTOR_COUNT:
		/* XXX autoguess media size, subtract offset */
		*up = (4 * 1024 * 1024) / FLASH_BLOCKLEN;
		return (RES_OK);
	case GET_BLOCK_SIZE:
		/* XXX why? */
		return (RES_ERROR);
#if 0 /* XXX REVISIT TRIM */
	case CTRL_ERASE_SECTOR:
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

		flash_erase_sectors(up[0], up[1] - up[0] + 1);

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
		/* Set write-protect bits */
		spi_start_transaction(IO_SPI_FLASH);
		spi_byte(IO_SPI_FLASH, SPI_CMD_WRSR);
		spi_byte(IO_SPI_FLASH, 0x1c);
		#endif

		return (RES_OK);
#endif /* XXX revisit TRIM */
#endif /* !DISKIO_RO */
	case CTRL_SYNC:
		return (RES_OK);
	default:
		return (RES_ERROR);
	}
}


struct diskio_sw flash_sw = {
	.read	= flash_read,
	.write	= flash_write,
	.ioctl	= flash_ioctl,
	.status	= flash_init_status,
	.init	= flash_init_status
};

