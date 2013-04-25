
#include <sys/param.h>
#include <sdcard.h>
#include <io.h>
#include <spi.h>
#include <stdio.h>
#include <stdlib.h>

#include <fatfs/ff.h>

#include <mips/asm.h>


int fib(int);
void rectangle(int x0, int y0, int x1, int y1, int color);


#define SECTOR_SIZE     512     /* buffer size */

int first_run = 1;


uint8_t *fb = (void *) FB_BASE;
uint16_t *fb16 = (void *) FB_BASE;
FATFS fh;


int
fib(int n)
{

	if (n < 2)
		return (n);
	else
		return (fib(n-1) + fib(n-2));
} 


void
rectangle(int x0, int y0, int x1, int y1, int color)
{
	int tmp, x, yoff;

	if (x1 < x0) {
		tmp = x0;
		x0 = x1;
		x1 = tmp;
	}
	if (y1 < y0) {
		tmp = y0;
		y0 = y1;
		y1 = tmp;
	}

	while (y0 <= y1) {
		yoff = y0 * 512;
		for (x = x0; x <= x1; x++)
			fb[yoff + x] = color;
		y0++;
	}
}


void
cpu1_test()
{
	uint32_t i, t0, t1;
	uint32_t *p;

	do {
		p = (void *) FB_BASE;
		for (i = 0; i < 288 * 512 / sizeof(*p); i++) {
			t0 = *p;
			t1 = (t0 + (1 << 24)) & 0xff000000;
			t1 += (t0 + (1 << 16)) & 0xff0000;
			t1 += (t0 + (1 << 8)) & 0xff00;
			t1 += (t0 + 1) & 0xff;
			*p++ = t1;
		}
		i = sio_getchar(0);
	} while (i != ' ' && i != 's');
}


int
main(void)
{
	FIL fp;
	int res, x0, y0, x1, y1;
	uint32_t color, tmp, freq_khz;
	uint32_t start, end;
	int r, g, b, luma, chroma, saturation;

	if (first_run == 0)
		cpu1_test();
	first_run = 0;

	printf("Hello, MIPS world!\n\n");

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);

	printf("f32c @ %d.%03d MHz, code running from ",
	    freq_khz / 1000, freq_khz % 1000);
#ifdef BRAM
	printf("FPGA block RAM.\n\n");
#else
	printf("external static RAM.\n\n");
#endif

	do {
		res = sio_getchar(0);
	} while (res != ' ' && res != 's');

	if (res == 's') {
		unsigned int i, last = 0;
		uint32_t t, *p;
		do {
			t = 0;
			p = (void *) FB_BASE;
			RDTSC(start);
			for (i = 0; i < 288 * 512 / sizeof(*p) / 4; i++) {
				t += *p++;
				t += *p++;
				t += *p++;
				t += *p++;
			}
			RDTSC(end);
			if (t != last || res == 't')
				printf("csum = %08x, %d bytes read in %d us\n",
				    t, 288 * 512,
				    (end - start) / (freq_khz / 1000));
			last = t;
			res = sio_getchar(0);
		} while (res != ' ' && res != 's');
	}

	RDTSC(start);
	for (tmp = 0; tmp <= 25; tmp++)
		printf("fib(%d) = %d\n", tmp, fib(tmp));
	RDTSC(end);
	printf("\nFibonacci completed in %d ms\n", (end - start) / freq_khz);

	/* Initialize SPI bulk-read transaction */
	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x0b); /* High-speed read */
	spi_byte(SPI_PORT_FLASH, 0);
	spi_byte(SPI_PORT_FLASH, 0);
	spi_byte(SPI_PORT_FLASH, 0);
	spi_byte_in(SPI_PORT_FLASH); /* dummy byte, ignored */

	RDTSC(start);
	color = 0;
	for (int i = 0; i < 1024 * 1024 / 4; i++) {
		tmp = spi_byte_in(SPI_PORT_FLASH);
		tmp = (tmp << 8) | spi_byte_in(SPI_PORT_FLASH);
		tmp = (tmp << 8) | spi_byte_in(SPI_PORT_FLASH);
		tmp = (tmp << 8) | spi_byte_in(SPI_PORT_FLASH);
		color += tmp;
	}
	RDTSC(end);
	printf("\n1 MByte fetched via spi_byte_in() from Flash to registers"
	    " in %d ms\n", (end - start) / freq_khz);

	RDTSC(start);
	for (int j = 0; j < 8; j++) {
		int *p = (int *) fb;
		for (int i = 0; i < 128 * 1024 / 4; i++) {
			tmp = spi_byte_in(SPI_PORT_FLASH);
			tmp = (tmp << 8) | spi_byte_in(SPI_PORT_FLASH);
			tmp = (tmp << 8) | spi_byte_in(SPI_PORT_FLASH);
			tmp = (tmp << 8) | spi_byte_in(SPI_PORT_FLASH);
			*p++ = tmp;
		}
	}
	RDTSC(end);
	printf("1 MByte fetched via spi_byte_in() from Flash to SRAM"
	    " in %d ms\n", (end - start) / freq_khz);

	RDTSC(start);
	for (int j = 0; j < 8; j++)
		spi_block_in(SPI_PORT_FLASH, fb, 128 * 1024);
	RDTSC(end);
	printf("1 MByte fetched via spi_block_in() from Flash to SRAM"
	    " in %d ms\n\n", (end - start) / freq_khz);
	while (sio_getchar(0) != ' ') {}

	printf("8 i 16 bitne palete boja (tipka 't' za odabir prikaza)\n");
	rectangle(0, 0, 511, 15, 15);
	rectangle(0, 272, 511, 287, 15);
	tmp = 0;
	int mode = 0;
	do {
		uint32_t i;
		uint8_t *p8 = (void *) &fb[16 * 512];
		uint16_t *p16 = (void *) &fb16[16 * 512];

                OUTB(IO_FB, !(mode == 0));

		for (y0 = 0; y0 < 256; y0++) {
			if (mode == 0) {
				for (x0 = 0; x0 < 16; x0++) {
					color = (x0 + (y0 & 0xf0)) & 0xff;
					for (i = 0; i < 32 / sizeof(*p8); i++)
						*p8++ = color;
				}
			} else {
				for (x0 = 0; x0 < 512; x0++) {
					saturation = (tmp / 64) & 0xf;
					chroma = x0 / 8;
					luma = y0 / 2;
					if (saturation < 4) {
						color = (luma << 9)
						    + ((chroma / 2) << 4)
						    + saturation;
					} else {
						color = ((luma / 2) << 10)
						    + (chroma << 4)
						    + saturation;
					}
					*p16++ = color;
				}
			}
		}

		if (mode == 0) {
			for (x0 = 0; x0 < 512; x0++) {
				fb[x0 + 16 * 512 + 512 * (x0 / 2)] = 31;
				fb[x0 + 512 * (256 + 16) - 512 * (x0 / 2)] = 31;
			}
			for (x0 = 0; x0 < 512; x0++) {
				fb[x0 + 16 * 512 + 512 * (x0 & 0xff)] = 31;
				fb[x0 + 512 * (256 + 16) - 512 * (x0 & 0xff)] = 31;
			}
		} else if (mode == 1) {
			for (x0 = 0; x0 < 512; x0++) {
				fb16[x0 + 16 * 512 + 512 * (x0 / 2)] = 63 << 10;
				fb16[x0 + 512 * (256 + 16) - 512 * (x0 / 2)] = 63 << 10;
			}
			for (x0 = 0; x0 < 512; x0++) {
				fb16[x0 + 16 * 512 + 512 * (x0 & 0xff)] = 63 << 10;
				fb16[x0 + 512 * (256 + 16) - 512 * (x0 & 0xff)] = 63 << 10;
			}
		}

		tmp++;
		res = sio_getchar(0);
		if (res == 't') {
			mode++;
			if (mode == 3)
				mode = 0;
		}
		if (res == 27)
			return(0);
	} while (res != ' ');

	printf("Vertikalne crte u boji (8-bitna paleta)\n");
	OUTB(IO_FB, 0);
	rectangle(0, 0, 511, 287, 0);
	while (sio_getchar(0) != ' ') {
		for (x0 = 0; x0 < 512; x0 += 2)
			for (y0 = 0; y0 < 256; y0++)
				fb[x0 + 512 * y0 + 512 * 16] = tmp >> 4;
		tmp++;
	}

	printf("Pravokutnici u boji\n");
	while (sio_getchar(0) != ' ') {
		x0 = random() & 0x1ff;
		x1 = random() & 0x1ff;
		y0 = (random() & 0xff) + (tmp & 0x1f);
		y1 = (random() & 0xff) + (tmp & 0x1f);
		color = tmp >> 4;
		rectangle(x0, y0, x1, y1, color);
		rectangle(0, 0, 511, 0, tmp++ >> 4);
		uint32_t *p0, *p1;
		for (p0 = (void *) &fb[512 * 287],
		    p1 = (void *) &fb[512 * 288]; (void *) p0 > (void *) fb;) {
			*(--p1) = *(--p0);
		}
	}

	/* Procitaj sliku iz datoteke i ispisi na ekran */
	if (sdcard_init() || sdcard_cmd(SD_CMD_SEND_CID, 0) ||
	    sdcard_read((char *) fb, 16)) {
		printf("Nije pronadjena MicroSD kartica!\n");
		return (-1);
	}
	f_mount(0, &fh);
	if (f_open(&fp, "zastav~1.raw", FA_READ)) {
		printf("Nije pronadjena datoteka /zastav~1.raw!\n");
		return (-1);
	}
	printf("Citam datoteku /zastav~1.raw...\n");
	for (int i = 0; i < 288 * SECTOR_SIZE; i += SECTOR_SIZE) {
		unsigned char *ib = &fb[i];

		for (x0 = 0; x0 < 3; x0++, ib += SECTOR_SIZE)
			if ((res = f_read(&fp, ib, SECTOR_SIZE, &tmp))) {
				printf("\nf_read() failed!\n");
				return (-1);
			}

		ib = &fb[i];
		for (x0 = 0; x0 < 512; x0++) {
			r = *ib++;
			g = *ib++;
			b = *ib++;
			luma = r + g + b;
			if (r > g + b) {
				if (g > b)
					color = 32 + 8 + (luma >> 6) * 16;
				else
					color = 32 + 7 + (luma >> 6) * 16;
			}
			else if (g > r + b)
				color = 32 + 13 + (luma >> 6) * 16;
			else if (b > r + g)
				color = 32 + 2 + (luma >> 6) * 16;
			else if (b > ((r + g) * 3) >> 2)
				color = 32 + 1 + (luma >> 6) * 16;
			else 
				color = (luma / 3) >> 3;
			fb[x0 + i] = color;
		}
	}

	return (0);
}
