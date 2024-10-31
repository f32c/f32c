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
 */

#include <time.h>

#include <dev/io.h>
#include <dev/sdcard.h>
#include <dev/spi.h>

#include <fatfs/ff.h>
#include <fatfs/diskio.h>


#if defined(_FS_READONLY) && _FS_READONLY == 1
#define	DISKIO_RO
#endif

#define	FLASH_BLOCKLEN	4096
#define FLASH_FAT_OFFSET 0x100000

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

#define USE_EWSR 0
#define USE_WREN_BEFORE_WRSR 0
#define USE_WRSR 0


#ifndef DISKIO_RO
static void
busy_wait()
{
	do {
		spi_start_transaction(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, SPI_CMD_RDSR);
	} while (spi_byte(IO_SPI_FLASH, SPI_CMD_RDSR) & 1);
}


static void
flash_erase_sectors(int start, int cnt)
{
	int addr, sum, i;

	addr = FLASH_FAT_OFFSET / 256 + start * (FLASH_BLOCKLEN / 256);
	for (; cnt > 0; cnt--, addr += (FLASH_BLOCKLEN / 256)) {
		/* Skip already blank sectors */
		spi_start_transaction(IO_SPI_FLASH, 0);
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
		spi_start_transaction(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
		spi_start_transaction(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, SPI_CMD_ERSEC);
		spi_byte(IO_SPI_FLASH, addr >> 8);
		spi_byte(IO_SPI_FLASH, addr);
		spi_byte(IO_SPI_FLASH, 0);
		busy_wait();
	}
}


static int
flash_disk_write(const uint8_t *buf, uint32_t SectorNumber,
    uint32_t SectorCount)
{
	int mfg_id, addr, i, j, in_aai = 0;

	/* Get SPI chip ID */
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_RDID2);
	spi_byte(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, 0);
	mfg_id = spi_byte(IO_SPI_FLASH, 0);
	if (mfg_id == 0xff) {
		spi_start_transaction(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, SPI_CMD_RDID);
		mfg_id = spi_byte(IO_SPI_FLASH, 0);
	}

	#if USE_EWSR
	/* Enable Write Status Register */
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_EWSR);
	#endif

	#if USE_WREN_BEFORE_WRSR
	/* Write enable */
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
	#endif

	#if USE_WRSR
	/* Clear write-protect bits */
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WRSR);
	spi_byte(IO_SPI_FLASH, 0);
	#endif

	/* Erase sectors */
	flash_erase_sectors(SectorNumber, SectorCount);

	addr = FLASH_FAT_OFFSET / 256 + SectorNumber * (FLASH_BLOCKLEN / 256);
	for (; SectorCount > 0; SectorCount--)
		switch (mfg_id) {
		case SPI_MFG_SST:
			/* Write enable */
			spi_start_transaction(IO_SPI_FLASH, 0);
			spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);

			for (i = 0; i < FLASH_BLOCKLEN; i += 2) {
				spi_start_transaction(IO_SPI_FLASH, 0);
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
			break;
		case SPI_MFG_CYPRESS:
		case SPI_MFG_ISSI1:
		case SPI_MFG_ISSI2:
		case SPI_MFG_SPANS:
			for (i = 0; i < FLASH_BLOCKLEN; i += 256, addr++) {
				/* Write enable */
				spi_start_transaction(IO_SPI_FLASH, 0);
				spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);

				spi_start_transaction(IO_SPI_FLASH, 0);
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
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WRDI);
	busy_wait();

	#if USE_EWSR
	/* Enable Write Status Register */
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_EWSR);
	#endif

	#if USE_WREN_BEFORE_WRSR
	/* Write enable */
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
	#endif

	#if USE_WRSR
	/* Set write-protect bits */
	spi_start_transaction(IO_SPI_FLASH, 0);
	spi_byte(IO_SPI_FLASH, SPI_CMD_WRSR);
	spi_byte(IO_SPI_FLASH, 0x1c);
	#endif

	return (RES_OK);
}
#endif /* !DISKIO_RO */


static int
flash_disk_read(uint8_t *buf, uint32_t SectorNumber, uint32_t SectorCount)
{
	int addr = FLASH_FAT_OFFSET / 256 + SectorNumber * (FLASH_BLOCKLEN / 256);

	for (; SectorCount > 0; SectorCount--) {
		spi_start_transaction(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, SPI_CMD_FASTRD);
		spi_byte(IO_SPI_FLASH, addr >> 8);
		spi_byte(IO_SPI_FLASH, addr);
		spi_byte(IO_SPI_FLASH, 0);
		spi_byte(IO_SPI_FLASH, 0); /* dummy byte, ignored */
		spi_block_in(IO_SPI_FLASH, buf, SectorCount * FLASH_BLOCKLEN);
	}
	return (RES_OK);
}


DSTATUS
disk_initialize(BYTE drive)
{

	switch (drive) {
	case 0:
		return (RES_OK);
	case 1:
		return (sdcard_disk_initialize());
	default:
		return (RES_ERROR);
	}
}


DSTATUS
disk_status(BYTE drive)
{

	switch (drive) {
	case 0:
		return (RES_OK);
	case 1:
		return (sdcard_disk_status());
	default:
		return (RES_ERROR);
	}
}


DRESULT
disk_read(BYTE pdrv, BYTE* buff, LBA_t sector, UINT count)
{

	switch (pdrv) {
	case 0:
		return (flash_disk_read(buff, sector, count));
	case 1:
		return (sdcard_disk_read(buff, sector, count));
	default:
		return (RES_ERROR);
	}
}


#ifndef DISKIO_RO
DRESULT
disk_write(BYTE pdrv, const BYTE* buff, LBA_t sector, UINT count)
{
	uint8_t *buf = (void *) buff;

	switch (pdrv) {
	case 0:
		return (flash_disk_write(buf, sector, count));
	case 1:
		return (sdcard_disk_write(buf, sector, count));
	default:
		return (RES_ERROR);
	}
}
#endif /* !DISKIO_RO */


DRESULT
disk_ioctl(BYTE drive, BYTE cmd, void* buf)
{
	WORD *up = buf;

	switch (cmd) {
	case GET_SECTOR_SIZE:
		if (drive == 0)
			*up = FLASH_BLOCKLEN;
		else
			*up = 512;
		return (RES_OK);
#ifndef DISKIO_RO
	case GET_SECTOR_COUNT:
		if (drive == 0) {
			*up = ((1 << 22) - FLASH_FAT_OFFSET) / FLASH_BLOCKLEN;
			return (RES_OK);
		}
		return (RES_ERROR);
	case CTRL_TRIM:
		if (drive == 0) {
			#if USE_EWSR
			/* Enable Write Status Register */
			spi_start_transaction(IO_SPI_FLASH, 0);
			spi_byte(IO_SPI_FLASH, SPI_CMD_EWSR);
			#endif

			#if USE_WREN_BEFORE_WRSR
			/* Write enable */
			spi_start_transaction(IO_SPI_FLASH, 0);
			spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
			#endif

			#if USE_WRSR
			/* Clear write-protect bits */
			spi_start_transaction(IO_SPI_FLASH, 0);
			spi_byte(IO_SPI_FLASH, SPI_CMD_WRSR);
			spi_byte(IO_SPI_FLASH, 0);
			#endif

			flash_erase_sectors(up[0], up[1] - up[0] + 1);

			#if USE_EWSR
			/* Enable Write Status Register */
			spi_start_transaction(IO_SPI_FLASH, 0);
			spi_byte(IO_SPI_FLASH, SPI_CMD_EWSR);
			#endif

			#if USE_WREN_BEFORE_WRSR
			/* Write enable */
			spi_start_transaction(IO_SPI_FLASH, 0);
			spi_byte(IO_SPI_FLASH, SPI_CMD_WREN);
			#endif

			#if USE_WRSR
			/* Set write-protect bits */
			spi_start_transaction(IO_SPI_FLASH, 0);
			spi_byte(IO_SPI_FLASH, SPI_CMD_WRSR);
			spi_byte(IO_SPI_FLASH, 0x1c);
			#endif
		}
		return (RES_OK);
#endif /* !DISKIO_RO */
	case CTRL_SYNC:
		return (RES_OK);
	default:
		return (RES_ERROR);
	}
}


DWORD
get_fattime(void)
{
	time_t t;
	struct tm tm;
	DWORD res;

	t = time(NULL);
	gmtime_r(&t, &tm);

	res = (tm.tm_year - 80) << 25 | (tm.tm_mon + 1) << 21
	    | tm.tm_mday << 16 | tm.tm_hour << 11
	    | tm.tm_min << 5 | tm.tm_sec >> 1;

	return (res);
}
