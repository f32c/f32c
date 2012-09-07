
#include <sys/param.h>
#include <sdcard.h>
#include <io.h>
#include <sio.h>
#include <spi.h>
#include <stdio.h>

#include <fatfs/ff.h>

#define	PAGE_SIZE	4096	/* SPI flash minimum unit of work */
#define	SECTOR_SIZE	512	/* FAT sector size */

//void (*sio_idle_fn)(void) = NULL;

FATFS fh;
char buf[SECTOR_SIZE];

#define	CMD_READID		1
#define	CMD_ENABLE_WRITE	2
#define	CMD_DISABLE_WRITE	3
#define	CMD_WRITE_PAGE		4

static void
spi_wait()
{

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x05); /* RDSR */
	do {} while (spi_byte(SPI_PORT_FLASH, 0x05) & 1);
}


static int
dispatch(int cmd, uint addr)
{
	int error = 0;
	int i;
	char *cp;

	/* Check that the device is idle before issuing next command */
	spi_wait();

	switch (cmd) {
	case CMD_ENABLE_WRITE:
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x50); /* EWSR */

		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x01); /* WRSR */
		spi_byte(SPI_PORT_FLASH, 0); /* Clear write-protect bits */
		break;

#if 0
	case CMD_DISABLE_WRITE:
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x50); /* EWSR */

		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x01); /* WRSR */
		spi_byte(SPI_PORT_FLASH, 0x1c);	/* Set write-protect bits */
		break;
#endif

	case CMD_WRITE_PAGE:
		cp = buf;


#if 1
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0xad); /* AAI write mode */
		spi_byte(SPI_PORT_FLASH, addr >> 16);
		spi_byte(SPI_PORT_FLASH, addr >> 8);
		spi_byte(SPI_PORT_FLASH, addr);
		spi_byte(SPI_PORT_FLASH, *cp++);
		spi_byte(SPI_PORT_FLASH, *cp++);

		for (i = 2; i < PAGE_SIZE; i++) {

			spi_wait();

			spi_start_transaction(SPI_PORT_FLASH);
			spi_byte(SPI_PORT_FLASH, 0xad); /* AAI write mode */
			spi_byte(SPI_PORT_FLASH, *cp++);
			spi_byte(SPI_PORT_FLASH, *cp++);
		}
#else
		int j;
#endif

		spi_wait();

		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x04); /* WRDI */

		spi_wait();

		/* XXX cemu ovo?!? */
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x0b); /* High-speed read */
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_byte(SPI_PORT_FLASH, 0);
		break;

	default:
		error = -1;
		break;
	}

	return (error);
}


void
main(void)
{
	FIL fp;
	int i, j, k, addr, res;
	uint got;

        if (sdcard_init() || sdcard_cmd(SD_CMD_SEND_CID, 0) ||
            sdcard_read((char *) buf, 16))
                return;

        f_mount(0, &fh);
	if (f_open(&fp, "ulx2s_~1.img", FA_READ))
		return;

	dispatch(CMD_ENABLE_WRITE, 0);
	for (i = 0; i < 1024; i++) {
		printf("%d ", i);
		OUTB(IO_LED, i / 4);

		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x06); /* WREN */
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x20); /* Sector erase */
		spi_byte(SPI_PORT_FLASH, (i * PAGE_SIZE) >> 16);
		spi_byte(SPI_PORT_FLASH, (i * PAGE_SIZE) >> 8);
		spi_byte(SPI_PORT_FLASH, 0);
		spi_wait();

		for (j = 0; j < PAGE_SIZE / SECTOR_SIZE; j++) {
			if ((res = f_read(&fp, buf, SECTOR_SIZE, &got)))
				goto done;
			if (got != SECTOR_SIZE)
				goto done;

			for (k = 0; k < SECTOR_SIZE; k++) {
				/* XXX do we need this? */
				spi_start_transaction(SPI_PORT_FLASH);
				spi_byte(SPI_PORT_FLASH, 0x06); /* WREN */

				addr = i * PAGE_SIZE + j * SECTOR_SIZE + k;
				spi_start_transaction(SPI_PORT_FLASH);
				spi_byte(SPI_PORT_FLASH, 0x02); /* Byte prog. */
				spi_byte(SPI_PORT_FLASH, addr >> 16);
				spi_byte(SPI_PORT_FLASH, addr >> 8);
				spi_byte(SPI_PORT_FLASH, addr);
				spi_byte(SPI_PORT_FLASH, buf[k]);
				spi_wait();
			}

			spi_start_transaction(SPI_PORT_FLASH);
			spi_byte(SPI_PORT_FLASH, 0x04); /* WRDI */
			spi_wait();
		}
	}
done:
	dispatch(CMD_DISABLE_WRITE, 0);
}
