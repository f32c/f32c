
#include <sys/param.h>
#include <sdcard.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>

#include <fatfs/ff.h>

#include <mips/asm.h>


int fib(int);
void rectangle(int x0, int y0, int x1, int y1, int color);


#define SECTOR_SIZE     512     /* buffer size */

unsigned char *ib = (void *) 0x80040000;
unsigned char *fb = (void *) 0x800c0000;
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


int
main(void)
{
	FIL fp;
	int res, x0, y0, x1, y1, color;
	uint32_t tmp, freq_khz;
	uint32_t start, end;

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

	RDTSC(start);
	for (tmp = 0; tmp <= 20; tmp++)
		printf("fib(%d) = %d\n", tmp, fib(tmp));
	RDTSC(end);
	printf("\nCompleted in %d ms\n", (end - start) / freq_khz);

	printf("256-bitna paleta\n");
	rectangle(0, 0, 511, 15, 16);
	rectangle(0, 272, 511, 287, 16);
	for (x0 = 0; x0 < 512; x0++)
		for (y0 = 0; y0 < 256; y0++)
			fb[x0 + 512 * y0 + 512 * 16] =
				x0 / 32 + (y0 & 0xf0);
	while (sio_getchar(0) != ' ') {}

	printf("Vertikalne crte u boji\n");
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
		int *p0, *p1;
		for (p0 = (int *) &fb[512 * 287],
		    p1 = (int *) &fb[512 * 288]; p0 > (int *) fb;)
			*(--p1) = *(--p0);
	}

	/* Procitaj sliku iz datoteke i ispisi na ekran */
	if (sdcard_init() || sdcard_cmd(SD_CMD_SEND_CID, 0) ||
	    sdcard_read((char *) ib, 16)) {
		printf("Nije pronadjena MicroSD kartica!\n");
		return (-1);
	}
	f_mount(0, &fh);
	if (f_open(&fp, "zastav~1.raw", FA_READ)) {
		printf("Nije pronadjena datoteka /zastav~1.raw!\n");
		return (-1);
	}
	printf("Citam datoteku /zastav~1.raw...\n");
	for (int i = 0; i < 3 * 288 * SECTOR_SIZE; i += SECTOR_SIZE) {
		if ((res = f_read(&fp, &ib[i], SECTOR_SIZE, &tmp))) {
			printf("\nf_read() failed!\n");
			return (-1);
		}
	}
	tmp = 0;
	printf("Obrada slike...\n");
	for (y0 = 0; y0 < 288; y0++) {
		int r, g, b, luma;
		for (x0 = 0; x0 < 512; x0++) {
			r = ib[tmp++];
			g = ib[tmp++];
			b = ib[tmp++];
			luma = r + g + b;
			if (r > g + b)
				color = 32 + 8 + (luma >> 6) * 16;
			else if (g > r + b)
				color = 32 + 3 + (luma >> 6) * 16;
			else if (b > r + g)
				color = 32 + 13 + (luma >> 6) * 16;
			else if (b > ((r + g) * 3) >> 2)
				color = 32 + 14 + (luma >> 6) * 16;
			else
				color = (luma / 3) >> 3;
			fb[x0 + y0 * 512] = color;
		}
	}

	return (0);
}
