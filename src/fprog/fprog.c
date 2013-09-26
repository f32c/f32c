
#include <sys/param.h>
#include <fcntl.h>
#include <io.h>
#include <sio.h>
#include <spi.h>
#include <stdio.h>
#include <unistd.h>

#include <fatfs/ff.h>
#include <fatfs/diskio.h>


#define	SECTOR_BURST	16
#define	BLOCK_SIZE	4096 * SECTOR_BURST	/* buffer size */


char *buf = (char *) 0x80080000;


#define IMAGE_NAME	"1:ulx2s_4m.img"


void
main(void)
{
	int fd, i, got;
	int j, sum;

again:
	printf("\nULX2S SPI Flash programer v0.1\n\n");

	if ((fd = open(IMAGE_NAME, 0)) < 0) {
		printf("Nije pronadjena datoteka %s!\n", IMAGE_NAME);
		printf("\nPritisnite tipku <ESC> za izlaz, ili "
		    "umetnite karticu u MicroSD utor\n"
		    "i pritisnite bilo koju tipku za ponovni pokusaj.\n\n");
		i = getchar();
		if (i != 27)
			goto again;
		return;
	}

	printf("Brisem SPI flash...\n");
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x50); /* EWSR */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x01); /* WRSR */
	spi_byte(SPI_PORT_FLASH, 0); /* Clear write-protect bits */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x06); /* WREN */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x60); /* Chip erase */

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x05); /* RDSR */
	do {} while (spi_byte(SPI_PORT_FLASH, 0x05) & 1);

	printf("Pisem sektore...\n");
	for (i = 0; i < 1024; i += SECTOR_BURST) {
		printf("\r%d", i);
		OUTB(IO_LED, i >> 2);

		if ((got = read(fd, buf, BLOCK_SIZE)) < 0) {
			printf("\nread() failed!\n");
			goto done;
		}

		if (got != BLOCK_SIZE) {
			printf("\nread(): short read!\n");
			goto done;
		}

		/* Preskoci prazne sektore */
		for (sum = -1, j = 0; j < BLOCK_SIZE; j += 4)
			sum &= *((int *) &buf[j]);
		if (sum == -1)
			continue;

		disk_write(0, (BYTE *) buf, i, SECTOR_BURST);
	}
	printf("\r%d", i);

done:
	printf("\nGotovo!\n\n");

	printf("Pritisnite bilo koju tipku NA PLOCICI za izlaz iz programa\n");
	do {
		INB(i, IO_PUSHBTN);
	} while (i == 0);
}
