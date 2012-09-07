
#include <sys/param.h>
#include <sdcard.h>
#include <io.h>
#include <sio.h>
#include <spi.h>
#include <stdio.h>

#include <fatfs/ff.h>


#define	PAGE_SIZE	4096	/* SPI flash minimum unit of work */
#define	SECTOR_SIZE	512	/* buffer size */


FATFS fh;
char buf[SECTOR_SIZE];


static void
spi_wait()
{

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x05); /* RDSR */
	do {} while (spi_byte(SPI_PORT_FLASH, 0x05) & 1);
}


void
main(void)
{
	FIL fp;
	int i, j, k, res;
	uint got;

	if (sdcard_init() || sdcard_cmd(SD_CMD_SEND_CID, 0) ||
	    sdcard_read((char *) buf, 16)) {
		printf("Nije pronadjena MicroSD kartica!\n");
		return;
	}

	f_mount(0, &fh);
	if (f_open(&fp, "ulx2s_~1.img", FA_READ)) {
		printf("Nije pronadjena datoteka /ulx2s_~1.img!\n");
		return;
	}

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x50); /* EWSR */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x01); /* WRSR */
	spi_byte(SPI_PORT_FLASH, 0); /* Clear write-protect bits */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x06); /* WREN */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x60); /* Chip erase */
	spi_wait();

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x06); /* WREN */

	for (i = 0; i < 1024; i++) {
		printf("%d ", i);
		OUTB(IO_LED, i >> 2);

		for (j = 0; j < PAGE_SIZE / SECTOR_SIZE; j++) {
			if ((res = f_read(&fp, buf, SECTOR_SIZE, &got))) {
				printf("\nf_read() failed!\n");
				goto done;
			}
			if (got != SECTOR_SIZE) {
				printf("\nf_read(): short read!\n");
				goto done;
			}

			for (k = 0; k < SECTOR_SIZE; k += 2) {
				spi_wait();
				spi_start_transaction(SPI_PORT_FLASH);
				spi_byte(SPI_PORT_FLASH, 0xad); /* AAI write */
				if (i == 0 && j == 0 && k == 0) {
					spi_byte(SPI_PORT_FLASH, 0);
					spi_byte(SPI_PORT_FLASH, 0);
					spi_byte(SPI_PORT_FLASH, 0);
				}
				spi_byte(SPI_PORT_FLASH, buf[k]);
				spi_byte(SPI_PORT_FLASH, buf[k + 1]);
			}
		}
	}

done:
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x04); /* WRDI */
	spi_wait();

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x50); /* EWSR */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x01); /* WRSR */
	spi_byte(SPI_PORT_FLASH, 0x1c);	/* Set write-protect bits */

	printf("\nGotovo!\n");
}
