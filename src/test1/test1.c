
#include <sys/param.h>
#include <sdcard.h>
#include <io.h>
#include <spi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fb.h>

#include <fatfs/ff.h>

#include <mips/asm.h>


int fib(int);


int first_run = 1;


uint8_t *fb = (void *) FB_BASE;
uint16_t *fb16 = (void *) FB_BASE;
char *fnbuf;
int mode = 1;

FATFS fh;


FRESULT
scan_files(char* path)
{
	FRESULT res;
	FILINFO fno;
	DIR dir;
	int i;

	/* Open the directory */
	res = f_opendir(&dir, path);
	if (res != FR_OK)
		return (res);

	i = strlen(path);
	do {
		/* Read a directory item */
		res = f_readdir(&dir, &fno);
		if (res != FR_OK || fno.fname[0] == 0)
			break;

		/* Ignore dot entry */
		if (fno.fname[0] == '.')
			continue;

		/* Recursively scan subdirectories */
		if (fno.fattrib & AM_DIR) {
			path[i] = '/';
			strcpy(&path[i+1], fno.fname);
			res = scan_files(path);
			if (res != FR_OK)
				break;
			path[i] = 0;
		} else {
			strcpy(fnbuf, path);
			fnbuf += i;
			strcpy(fnbuf, fno.fname);
			fnbuf += strlen(fno.fname);
			*fnbuf++ = 0;
		}
	} while (1);

	return (res);
}


int
fib(int n)
{

	if (n < 2)
		return (n);
	else
		return (fib(n-1) + fib(n-2));
} 


static void
load_raw(char *fname)
{
	FIL fp;
	int r, g, b;
	uint32_t i, x, y, ssize;
	unsigned char *ib;

	if (f_open(&fp, fname, FA_READ))
		return;

	printf("Citam datoteku %s...\n", fname);
	if (fname[0] == '1' && fname[1] == ':')
		ssize = 512;	/* sdcard */
	else
		ssize = 4096;	/* flash */


	set_fb_mode(mode);

	for (i = 0; i < 288 * 512; i += ssize) {

		if (mode)
			ib = (void *) &fb16[i];
		else
			ib = (void *) &fb[i];

#if 0
		/* XXX bug in microsd low-level I/O library? */
		if (f_read(&fp, ib, 3 * ssize, &y)) {
			printf("\nf_read() failed!\n");
			f_close(&fp);
			return;
		}
#else
		f_read(&fp, ib, ssize, &y);
		f_read(&fp, ((char *) ib) + ssize, ssize, &y);
		f_read(&fp, ((char *) ib) + 2 * ssize, ssize, &y);
#endif

		if (mode)
			ib = (void *) &fb16[i];
		else
			ib = (void *) &fb[i];

		for (x = 0; x < ssize; x++) {
			r = *ib++;
			g = *ib++;
			b = *ib++;
			if (mode)
				fb16[x + i] = rgb2pal(r, g, b);
			else
				fb[x + i] = rgb2pal(r, g, b);
		}
	}
	f_close(&fp);
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
	int res, x0, y0, x1, y1;
	uint32_t color, tmp, freq_khz;
	uint32_t chroma, luma, saturation;
	uint32_t start, end;

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

	//goto slika;

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
	do {
		uint32_t i;
		uint8_t *p8 = (void *) &fb[16 * 512];
		uint16_t *p16 = (void *) &fb16[16 * 512];

                set_fb_mode(mode);

		for (y0 = 0; y0 < 256; y0++) {
			if (mode == 0) {
				for (x0 = 0; x0 < 16; x0++) {
					color = (x0 + (y0 & 0xf0)) & 0xff;
					for (i = 0; i < 32 / sizeof(*p8); i++)
						*p8++ = color;
				}
			} else {
				for (x0 = 0; x0 < 512; x0++) {
					saturation = (tmp / 2) & 0xf;
					chroma = x0 / 16;
					luma = y0;
					color = (saturation << 12) |
					    (chroma << 7) | (luma >> 1);
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
				fb16[x0 + 16 * 512 + 512 * (x0 / 2)] = 127;
				fb16[x0 + 512 * (256 + 16) - 512 * (x0 / 2)] = 127;
			}
			for (x0 = 0; x0 < 512; x0++) {
				fb16[x0 + 16 * 512 + 512 * (x0 & 0xff)] = 127;
				fb16[x0 + 512 * (256 + 16) - 512 * (x0 & 0xff)] = 127;
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
	set_fb_mode(0);
	rectangle(0, 0, 511, 287, 0);
	while (sio_getchar(0) != ' ') {
		for (x0 = 0; x0 < 512; x0 += 2)
			for (y0 = 0; y0 < 256; y0++)
				fb[x0 + 512 * y0 + 512 * 16] = tmp >> 2;
		tmp++;
	}

	printf("Pravokutnici u boji\n");
	while (sio_getchar(0) != ' ') {
		x0 = random() & 0x1ff;
		x1 = random() & 0x1ff;
		y0 = (random() & 0xff) + (tmp & 0x1f);
		y1 = (random() & 0xff) + (tmp & 0x1f);
		color = tmp >> 2;
		rectangle(x0, y0, x1, y1, color);
		rectangle(0, 0, 511, 0, tmp++ >> 4);
		uint32_t *p0, *p1;
		for (p0 = (void *) &fb[512 * 287],
		    p1 = (void *) &fb[512 * 288]; (void *) p0 > (void *) fb;) {
			*(--p1) = *(--p0);
		}
	}

slika:
	/* Procitaj sliku iz datoteke i ispisi na ekran */

	mode = 1; /* 16-bitni prikaz */

	f_mount(1, &fh);

	fnbuf = (void *) &fb16[512 * 300];
	*fnbuf = 0;

	scan_files("1:");
	*fnbuf = 0;
	fnbuf = (void *) &fb16[512 * 300];

	int l;
	for (;; fnbuf += l + 1) {
		l = strlen(fnbuf);
		if (l == 0)
			goto slika;
		if (l < 5)
			continue;
		if (strcmp(&fnbuf[l - 4], ".RAW") != 0)
			continue;

		load_raw(fnbuf);

		RDTSC(start);
		do {
			res = sio_getchar(0);
			if (res == 27)
				return(0);
			RDTSC(tmp);
		} while (res != ' ' && tmp - start < freq_khz * 1000);
	}

	/* XXX notreached! */
}
