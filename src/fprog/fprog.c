
#include <sys/param.h>
#include <fcntl.h>
#include <io.h>
#include <sio.h>
#include <spi.h>
#include <stdio.h>
#include <unistd.h>

#include <fatfs/ff.h>
#include <fatfs/diskio.h>


#define	SECTOR_BURST	32
#define	BLOCK_SIZE	4096 * SECTOR_BURST	/* buffer size */


char *buf = (char *) 0x80080000;


//#define IMAGE_NAME	"1:ulx2s_flash1.img"
#define IMAGE_NAME	"1:fat12_4m.img"


void
main(void)
{
	int fd, i, got;

	if ((fd = open(IMAGE_NAME, 0)) < 0) {
		printf("Nije pronadjena datoteka %s!\n", IMAGE_NAME);
		return;
	}

	for (i = 0; i < 1024; i += SECTOR_BURST) {
		printf("%d ", i);
		OUTB(IO_LED, i >> 2);

		if ((got = read(fd, buf, BLOCK_SIZE)) < 0) {
			printf("\nread() failed!\n");
			goto done;
		}

		if (got != BLOCK_SIZE) {
			printf("\nread(): short read!\n");
			goto done;
		}

		disk_write(0, (BYTE *) buf, i, SECTOR_BURST);
	}

done:
	printf("\nGotovo!\n");
}
