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
 *
 * $Id$
 */

#include <fcntl.h>
#include <spi.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <fatfs/diskio.h>


#define	SPI_MFG_SPANS   0x01
#define	SPI_MFG_SST	0xbf

#define	SECTOR_BURST	16
#define	BLOCK_SIZE	4096 * SECTOR_BURST	/* buffer size */


char *buf;


#define	IMAGE_NAME	"d:ulx2s_4m.img"


void
main(void)
{
	int fd, i, got;
	int j, sum;
	int man_id, dev_id;

	buf = malloc(BLOCK_SIZE);
	if (buf == NULL) {
		printf("malloc() failed!\n");
		exit(1);
	}

again:
	printf("\nULX2S SPI Flash programer v1.0\n\n");

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x90); /* RDID */
	spi_byte(SPI_PORT_FLASH, 0);
	spi_byte(SPI_PORT_FLASH, 0);
	spi_byte(SPI_PORT_FLASH, 0);
	man_id = spi_byte(SPI_PORT_FLASH, 0);
	dev_id = spi_byte(SPI_PORT_FLASH, 0);
	printf("SPI manufacturer ");
	switch (man_id) {
	case SPI_MFG_SST:
		printf("SST");
		break;
	case SPI_MFG_SPANS:
		printf("Spansion");
		break;
	default:
		printf("unknown");
		break;
	}
	printf(" (ID 0x%02x), ", man_id);
	printf("device ");
	switch (dev_id) {
	case 0x4a:
		printf("SST25VF032B");
		break;
	case 0x15:
		printf("S25FL132K");
		break;
	default:
		printf("unknown");
		break;
	}
	printf(" (ID 0x%02x)\n", dev_id);

	spi_start_transaction(SPI_PORT_FLASH);
	j = spi_byte(SPI_PORT_FLASH, 0x9f); /* JEDEC ID */
	printf("device type %02x, ", spi_byte(SPI_PORT_FLASH, 0));
	printf("capacity %02x\n", spi_byte(SPI_PORT_FLASH, 0));

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

	if (man_id != SPI_MFG_SPANS) {
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x60); /* Chip erase */
	}

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
