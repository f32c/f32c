
#include <sys/param.h>
#include <sdcard.h>
#include <spi.h>

#include <fatfs/diskio.h>


#if defined(_FS_READONLY) && _FS_READONLY == 1
#define DISKIO_RO
#endif

#define FLASH_BLOCKLEN  4096


#define	SPI_CMD_WREN	0x06
#define	SPI_CMD_WRDI	0x04
#define	SPI_CMD_WRSR	0x01
#define	SPI_CMD_RDSR	0x05
#define	SPI_CMD_EWSR	0x50


#ifndef DISKIO_RO
static void
busy_wait()
{

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, SPI_CMD_RDSR);
	do {} while (spi_byte(SPI_PORT_FLASH, SPI_CMD_RDSR) & 1);
}


static void
flash_erase_sectors(int start, int cnt)
{
	int addr, sum, i;

	addr = start * FLASH_BLOCKLEN;
	for (; cnt > 0; cnt--, addr += FLASH_BLOCKLEN) {
		/* Skip already blank sectors */
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x0b); /* High-speed read */
		spi_byte(SPI_PORT_FLASH, addr >> 16);
		spi_byte(SPI_PORT_FLASH, addr >> 8);
		spi_byte(SPI_PORT_FLASH, addr);
		spi_byte(SPI_PORT_FLASH, 0xff); /* dummy byte, ignored */
		for (i = 0, sum = 0xff; i < FLASH_BLOCKLEN; i++)
			sum &= spi_byte(SPI_PORT_FLASH, 0xff);
		if (sum == 0xff)
			continue;

		/* Write enable */
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, SPI_CMD_WREN);
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x20); /* 4K sector erase */
		spi_byte(SPI_PORT_FLASH, addr >> 16);
		spi_byte(SPI_PORT_FLASH, addr >> 8);
		spi_byte(SPI_PORT_FLASH, addr);
		busy_wait();
	}
}


static int
flash_disk_write(const uint8_t *buf, uint32_t SectorNumber, uint32_t SectorCount)
{
	int addr, i, in_aai = 0;

	/* Enable Write Status Register */
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, SPI_CMD_EWSR);

	/* Clear write-protect bits */
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, SPI_CMD_WRSR);
	spi_byte(SPI_PORT_FLASH, 0);

	/* Erase sectors */
	flash_erase_sectors(SectorNumber, SectorCount);

	/* Write enable */
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, SPI_CMD_WREN);

	addr = SectorNumber * FLASH_BLOCKLEN;
	for (; SectorCount > 0; SectorCount--, addr += FLASH_BLOCKLEN) {
		for (i = 0; i < FLASH_BLOCKLEN; i += 2) {
			spi_start_transaction(SPI_PORT_FLASH);
			spi_byte(SPI_PORT_FLASH, 0xad); /* AAI write */
			if (!in_aai) {
				in_aai = 1;
				spi_byte(SPI_PORT_FLASH, addr >> 16);
				spi_byte(SPI_PORT_FLASH, addr >> 8);
				spi_byte(SPI_PORT_FLASH, addr);
			}
			spi_byte(SPI_PORT_FLASH, *buf++);
			spi_byte(SPI_PORT_FLASH, *buf++);
			busy_wait();
		}
	}

	/* Write disable - exit AAI write mode */
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, SPI_CMD_WRDI);
	busy_wait();

	/* Enable Write Status Register */
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, SPI_CMD_EWSR);

	/* Set write-protect bits */
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, SPI_CMD_WRSR);
	spi_byte(SPI_PORT_FLASH, 0x1c);

	return (RES_OK);
}
#endif /* !DISKIO_RO */


static int
flash_disk_read(uint8_t *buf, uint32_t SectorNumber, uint32_t SectorCount)
{
	int addr = SectorNumber * FLASH_BLOCKLEN;

	for (; SectorCount > 0; SectorCount--) {
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x0b); /* High-speed read */
		spi_byte(SPI_PORT_FLASH, addr >> 16);
		spi_byte(SPI_PORT_FLASH, addr >> 8);
		spi_byte(SPI_PORT_FLASH, addr);
		spi_byte(SPI_PORT_FLASH, 0xff); /* dummy byte, ignored */
		spi_block_in(SPI_PORT_FLASH, buf, SectorCount * FLASH_BLOCKLEN);
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
		return(sdcard_disk_initialize());
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
		return(sdcard_disk_status());
	default:
		return (RES_ERROR);
	}
}


DRESULT
disk_read(BYTE drive, BYTE* Buffer, DWORD SectorNumber, BYTE SectorCount)
{

	switch (drive) {
	case 0:
		return(flash_disk_read(Buffer, SectorNumber, SectorCount));
	case 1:
		return(sdcard_disk_read(Buffer, SectorNumber, SectorCount));
	default:
		return (RES_ERROR);
	}
}


#ifndef DISKIO_RO
DRESULT
disk_write(BYTE drive, const BYTE* Buffer, DWORD SectorNumber, BYTE SectorCount)
{
	uint8_t *buf = (void *) Buffer;

	switch (drive) {
	case 0:
		return(flash_disk_write(buf, SectorNumber, SectorCount));
	case 1:
		return(sdcard_disk_write(buf, SectorNumber, SectorCount));
	default:
		return (RES_ERROR);
	}
}
#endif /* !DISKIO_RO */


DRESULT
disk_ioctl(BYTE drive, BYTE cmd, void* buf)
{
	uint32_t *up = buf;

	switch (cmd) {
	case GET_SECTOR_SIZE:
		if (drive == 0)
			*up = FLASH_BLOCKLEN;
		else
			*up = 512;
		return (RES_OK);
#ifndef DISKIO_RO
	case CTRL_ERASE_SECTOR:
		if (drive == 0) {
			/* Enable Write Status Register */
			spi_start_transaction(SPI_PORT_FLASH);
			spi_byte(SPI_PORT_FLASH, SPI_CMD_EWSR);

			/* Clear write-protect bits */
			spi_start_transaction(SPI_PORT_FLASH);
			spi_byte(SPI_PORT_FLASH, SPI_CMD_WRSR);
			spi_byte(SPI_PORT_FLASH, 0);

			flash_erase_sectors(up[0], up[1] - up[0] + 1);

			/* Enable Write Status Register */
			spi_start_transaction(SPI_PORT_FLASH);
			spi_byte(SPI_PORT_FLASH, SPI_CMD_EWSR);

			/* Set write-protect bits */
			spi_start_transaction(SPI_PORT_FLASH);
			spi_byte(SPI_PORT_FLASH, SPI_CMD_WRSR);
			spi_byte(SPI_PORT_FLASH, 0x1c);
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

	return (0);
}
