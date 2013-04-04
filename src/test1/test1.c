
#include <sys/param.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>

#include <mips/asm.h>


int fib(int);
void rectangle(int x0, int y0, int x1, int y1, int color);


char *fb = (char *) 0x800c0000;


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
	int x0, y0, x1, y1, color;
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

	/* Iscrtaj cijelu paletu */
	rectangle(0, 0, 511, 15, 16);
	rectangle(0, 272, 511, 287, 16);
	for (x0 = 0; x0 < 512; x0++)
		for (y0 = 0; y0 < 256; y0++)
			fb[x0 + 512 * y0 + 512 * 16] =
				x0 / 32 + (y0 & 0xf0);
	while (sio_getchar(0) != 27) {}

	/* Vertikalne crte u boji */
	rectangle(0, 0, 511, 287, 0);
	while (sio_getchar(0) != 27) {
		for (x0 = 0; x0 < 512; x0 += 2)
			for (y0 = 0; y0 < 256; y0++)
				fb[x0 + 512 * y0 + 512 * 16] = tmp >> 4;
		tmp++;
	}

	/* Pravokutnici u boji */
	while (sio_getchar(0) != 27) {
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

	return (0);
}
