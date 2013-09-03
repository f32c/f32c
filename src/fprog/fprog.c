
#include <sys/param.h>
#include <fcntl.h>
#include <io.h>
#include <sio.h>
#include <spi.h>
#include <stdio.h>
#include <unistd.h>


#define	PAGE_SIZE	4096	/* SPI flash minimum unit of work */
#define	SECTOR_SIZE	512	/* buffer size */


char buf[SECTOR_SIZE];


//#define IMAGE_NAME	"1:ulx2s_flash1.img"
#define IMAGE_NAME	"1:fat12_4m.img"


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
	int fd, i, j, k, got;

	if ((fd = open(IMAGE_NAME, 0)) < 0) {
		printf("Nije pronadjena datoteka %s!\n", IMAGE_NAME);
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
			if ((got = read(fd, buf, SECTOR_SIZE)) < 0) {
				printf("\nread() failed!\n");
				goto done;
			}
			if (got != SECTOR_SIZE) {
				printf("\nread(): short read!\n");
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
