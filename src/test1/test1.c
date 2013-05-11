
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
int mode = 1;


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


	set_fb_mode(mode);

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
fib(int n)
{

	if (n < 2)
		return (n);
	else
		return (fib(n-1) + fib(n-2));
} 


void
cpu1_test()
{
	uint32_t i;

	do {
		for (i = 0; i < 288 * 512; i++) {
			fb16[i] += 1;
		}
		i = sio_getchar(0);
	} while (i != ' ' && i != 's');
}


int
main(void)
{
	int res, x0, y0, x1, y1;
	uint32_t color, tmp, freq_khz;
	uint32_t start, end;
	uint32_t i, last;
	uint32_t t, *p;

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
		last = 0;
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

	set_fb_mode(1);

	printf("Crte\n");
	rectangle(0, 0, 511, 287, 0);
	while (sio_getchar(0) != ' ') {
		x0 = random() & 0x1ff;
		y0 = random() % 288;
		x1 = random() & 0x1ff;
		y1 = random() % 288;
		color = random();
		line(x0, y0, x1, y1, color);
	}

	printf("Krugovi\n");
	rectangle(0, 0, 511, 287, 0);
	while (sio_getchar(0) != ' ') {
		x0 = random() & 0x1ff;
		y0 = random() % 288;
		tmp = random() & 0x7f;
		color = random();
		filledcircle(x0, y0, tmp, color);
	}

	printf("Pravokutnici\n");
	while (sio_getchar(0) != ' ') {
		x0 = random() & 0x1ff;
		y0 = random() % 288;
		x1 = random() & 0x1ff;
		y1 = random() % 288;
		color = random();
		rectangle(x0, y0, x1, y1, color);
	}

#ifdef FAT
slika:
	/* Procitaj sliku iz datoteke i ispisi na ekran */

	mode = 1; /* 16-bitni prikaz */

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
			if (res == 27)
				return(0);
			RDTSC(tmp);
		} while (res != ' ' && tmp - start < freq_khz * 1000);
	}

	/* XXX notreached! */
#endif

	return (0);
}
