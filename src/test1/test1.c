
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


uint8_t *fb = (void *) FB_BASE;
uint16_t *fb16 = (void *) FB_BASE;
int mode;


#define FAT

#ifdef FAT
static FATFS fh;
static char *fnbuf;

static FRESULT
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

	for (i = 0; i < 288 * 512; i += ssize) {

		if (mode)
			ib = (void *) &fb16[i];
		else
			ib = (void *) &fb[i];

		if (f_read(&fp, ib, 3 * ssize, &y)) {
			printf("\nf_read() failed!\n");
			f_close(&fp);
			return;
		}

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
#endif


int
main(void)
{
	int res, x0, y0, x1, y1;
	uint32_t color, tmp, freq_khz;
	uint32_t start, end, i;

	printf("Hello, MIPS world!\n\n");

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);

	printf("f32c @ %d.%03d MHz, CPU #%d, code running from ",
	    freq_khz / 1000, freq_khz % 1000, tmp & 0xf);
#ifdef BRAM
	printf("FPGA block RAM.\n\n");
#else
	printf("external static RAM.\n\n");
#endif

	//goto slika;

switch_mode:
	mode = !mode;
	set_fb_mode(mode);
	if (mode)
		printf("16-bitna paleta\n");
	else
		printf("8-bitna paleta\n");

	printf("Crte\n");
	RDTSC(start);
	i = 0;
	while (sio_getchar(0) != ' ') {
		tmp = random();
		x0 = tmp & 0x1ff;
		y0 = ((tmp >> 16) & 0xff) + ((tmp >> 24) & 0x1f);
		color = (tmp >> 27);
		tmp = random();
		x1 = tmp & 0x1ff;
		y1 = ((tmp >> 16) & 0xff) + ((tmp >> 24) & 0x1f);
		color ^= (tmp >> 13);
		line(x0, y0, x1, y1, color);
		i++;
	}
	RDTSC(end);
	printf("%d iteracija u %d.%03d sekundi (%d ops / s)\n", i,
	    (end - start) / freq_khz / 1000,
	    (end - start) / freq_khz % 1000,
	    i * freq_khz / ((end - start) / 1000));

	printf("Krugovi\n");
	i = 0;
	RDTSC(start);
	while (sio_getchar(0) != ' ') {
		tmp = random();
		x0 = tmp & 0x1ff;
		y0 = ((tmp >> 16) & 0xff) + ((tmp >> 24) & 0x1f);
		color = (tmp >> 10);
		tmp = (tmp >> 20) & 0x7f;
		filledcircle(x0, y0, tmp, color);
		i++;
	}
	RDTSC(end);
	printf("%d iteracija u %d.%03d sekundi (%d ops / s)\n", i,
	    (end - start) / freq_khz / 1000,
	    (end - start) / freq_khz % 1000,
	    i * freq_khz / ((end - start) / 1000));

	printf("Pravokutnici\n");
	i = 0;
	RDTSC(start);
	while (sio_getchar(0) != ' ') {
		tmp = random();
		x0 = tmp & 0x1ff;
		y0 = ((tmp >> 16) % 0x1ff) - 128;
		color = (tmp >> 10);
		tmp = random();
		x1 = tmp & 0x1ff;
		y1 = ((tmp >> 16) % 0x1ff) - 128;
		rectangle(x0, y0, x1, y1, color);
		i++;
	}
	RDTSC(end);
	printf("%d iteracija u %d.%03d sekundi (%d ops / s)\n", i,
	    (end - start) / freq_khz / 1000,
	    (end - start) / freq_khz % 1000,
	    i * freq_khz / ((end - start) / 1000));

#ifdef FAT
slika:
	/* Procitaj sliku iz datoteke i ispisi na ekran */
	fnbuf = (void *) &fb16[512 * 300];
	*fnbuf = 0;

	f_mount(1, &fh); scan_files("1:");
	//f_mount(0, &fh); scan_files("");

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
			if (res == ' ')
				goto switch_mode;
			RDTSC(tmp);
		} while (res != ' ' && tmp - start < freq_khz * 5000);
	}
#endif
}
