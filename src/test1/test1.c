
#include <sys/param.h>
#include <sdcard.h>
#include <io.h>
#include <spi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <fb.h>

#include <fatfs/ff.h>
#include <tjpgd.h>

#include <mips/asm.h>


int fib(int);


#define	FB_BASE 0x800b0000

uint8_t *fb = (void *) FB_BASE;
uint16_t *fb16 = (void *) FB_BASE;
int mode;

uint32_t start, end, freq_khz;

#define FAT

#ifdef FAT
static FATFS fh;
static char *fnbuf;

static int old_ts;


/* User defined device identifier */
typedef struct {
    int fh;	   /* File handle */
    BYTE *fbuf;    /* Pointer to the frame buffer for output function */
    UINT wfbuf;    /* Width of the frame buffer [pix] */
} IODEV;


/*------------------------------*/
/* User defined input funciton  */
/*------------------------------*/

UINT in_func (JDEC* jd, BYTE* buff, UINT nbyte)
{
    IODEV *dev = (IODEV*)jd->device;   /* Device identifier for the session (5th argument of jd_prepare function) */
    UINT retval;

    if (buff) {
        /* Read bytes from input stream */
        retval = read(dev->fh, buff, nbyte);
    } else {
        /* Remove bytes from input stream */
        retval = lseek(dev->fh, nbyte, SEEK_CUR) ? nbyte : 0;
    }

#if 0
if (buff)
	printf("%s: read %d %d\n", __FUNCTION__, nbyte, retval);
else
	printf("%s: skip %d %d\n", __FUNCTION__, nbyte, retval);
#endif
    return (retval);
}


/*------------------------------*/
/* User defined output funciton */
/*------------------------------*/

UINT out_func (JDEC* jd, void* bitmap, JRECT* rect)
{
    IODEV *dev = (IODEV*)jd->device;
    UINT y, bws, bwd;
    BYTE *dst;
#if JD_FORMAT < JD_FMT_RGB32
    BYTE *src;
#else
    LONG *src;
#endif

#if 0
    /* Put progress indicator */
    if (rect->left == 0) {
	printf("\r%lu%%", (rect->top << jd->scale) * 100UL / jd->height);
    }
#endif

    /* Copy the decompressed RGB rectanglar to the frame buffer (assuming RGB888 cfg) */
#if JD_FORMAT < JD_FMT_RGB32
    src = (BYTE*)bitmap;
    bws = 3 * (rect->right - rect->left + 1);     /* Width of source rectangular [byte] */
#else
    src = (LONG*)bitmap;
    bws = (rect->right - rect->left + 1);     /* Width of source rectangular [byte] */
#endif
    dst = dev->fbuf + (mode + 1) * (rect->top * dev->wfbuf + rect->left);  /* Left-top of destination rectangular */
    bwd = (mode + 1) * dev->wfbuf;                         /* Width of frame buffer [byte] */
    for (y = rect->top; y <= rect->bottom; y++) {
#if JD_FORMAT < JD_FMT_RGB32
	for (uint32_t i = 0, j = 0; i < bws; i += 3, j += (mode + 1)) {
#else
	for (uint32_t i = 0, j = 0; i < bws; i++, j += (mode + 1)) {
#endif
		uint32_t color;
		
#if JD_FORMAT < JD_FMT_RGB32
		color = fb_rgb2pal(src[i], src[i+1], src[i+2]);
#else
		color = fb_rgb2pal(src[i] >> 16, (src[i] >> 8) & 0xff,
		    src[i] & 0xff);
#endif
		if (mode)
			*((uint16_t *) &dst[j]) = color;
		else
			dst[j] = color;
	}
        src += bws; dst += bwd;  /* Next line */
    }

    return 1;    /* Continue to decompress */
}


static void
display_timestamp(void)
{
	int *sp = (void *) 0x300;
	char buf[16];

	if (old_ts == *sp)
		return;
	old_ts = *sp;
	
	buf[0] = ((old_ts / 50) % 10) + '0';
	buf[1] = 0;

	fb_text(450, 30, buf, 0xffff, 0);
}


static FRESULT
scan_files(char* path)
{
	FRESULT res;
	FILINFO fno;
	DIR dir;
	int i;
	char *fname;
	static char lfn[_MAX_LFN + 1];

	fno.lfname = lfn;
	fno.lfsize = sizeof(lfn);

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

		if (lfn[0] == 0)
			fname = fno.fname;
		else
			fname = lfn;

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
			strcpy(fnbuf, fname);
			fnbuf += strlen(fname);
			*fnbuf++ = 0;
		}
	} while (1);

	return (res);
}


static void
load_jpg(char *fname)
{
	char work_buf[8192];
	JDEC jdec;
	JRESULT res;
	IODEV devid;

	devid.fh = open(fname, O_RDONLY);
	if (devid.fh < 0)
		return;

	printf("Citam datoteku %s... ", fname);

	res = jd_prepare(&jdec, in_func, work_buf, sizeof(work_buf), &devid);
	if (res == JDR_OK) {
#if 0
		printf("Image dimensions: %u by %u. %u bytes used.\n",
		    jdec.width, jdec.height, 3100 - jdec.sz_pool);
#endif

		devid.fbuf = (void *) 0x800b0000;
		devid.wfbuf = 512;

		RDTSC(start);
		res = jd_decomp(&jdec, out_func, 0);
		RDTSC(end);
#if 0
		if (res == JDR_OK)
			printf("\rOK  \n");
		else
			printf("Failed to decompress: rc=%d\n", res);
#endif
		printf("%f s\n", 0.001 * (end - start) / freq_khz);
	} else {
		printf("Failed to prepare: rc=%d\n", res);
	}
	close(devid.fh);
}


static void
load_raw(char *fname)
{
	int r, g, b;
	uint32_t i;
	unsigned char *ib = (void *) 0x80020000;
	int f;

	f = open(fname, O_RDONLY);
	if (f < 0)
		return;

	printf("Citam datoteku %s...\n", fname);
	int got = 0;
	RDTSC(start);
	got += read(f, ib, 288 * 512 * 3);
	RDTSC(end);
	close(f);
	printf("   %d bytes in %f s (%f bytes/s)\n", got,
	    0.001 * (end - start) / freq_khz,
	    got / (0.001 * (end - start) / freq_khz));

	for (i = 0; i < 512 * 288; i++) {
		r = *ib++;
		g = *ib++;
		b = *ib++;
		f = fb_rgb2pal(r, g, b);
		if (mode)
			fb16[i] = f;
		else
			fb[i] = f;
	}
	display_timestamp();
}
#endif


int
main(void)
{
	int res, x0, y0, x1, y1;
	uint32_t color, tmp, i;
	volatile uint8_t *p8;
	volatile uint32_t *p32;

	printf("Hello, MIPS world!\n\n");

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);

#if 0
	printf("f32c @ %d.%03d MHz, CPU #%d, code running from ",
	    freq_khz / 1000, freq_khz % 1000, tmp & 0xf);
#else
	printf("f32c @ %f MHz, CPU #%d, code running from ",
	    freq_khz / 1000.0, tmp & 0xf);
#endif
#ifdef BRAM
	printf("FPGA block RAM.\n\n");
#else
	printf("external static RAM.\n\n");
#endif

	printf("Framebuffer iskljucen: ");

switch_mode:
	tmp = 0;
	RDTSC(start);
	for (p32 = (void *) 0x80000000, i = 0; i < 256*1024; i += 8, p32 += 8) {
		p32[0]; p32[1]; p32[2]; p32[3]; p32[4]; p32[5]; p32[6]; p32[7];
	}
	RDTSC(end);
	double speed = 1 / (0.001 * (end - start) / freq_khz);
	printf("1 MByte procitan u %d.%03d sekundi (%f MB / s)\n",
	    (end - start) / freq_khz / 1000,
	    (end - start) / freq_khz % 1000,
	    speed);

	/* Ispitaj RAW konzistentnost */
	p8 = (void *) 0x800c0000;
	for (i = 0; p8 < (uint8_t *) 0x800f0000; i += 37) {
		p8[0] = i; p8[1] = i; p8[2] = i;
		tmp = p8[2];
		p8[1] = i; p8[2] = i; p8[3] = i;
		color = p8[1];
		if (tmp != (i & 0xff) || color != (i & 0xff))
			printf("%08x != %08x\n", i, tmp);
		p8++;
	} 

	mode = !mode;
	fb_set_mode(mode);
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
		fb_line(x0, y0, x1, y1, color);
		i++;
		display_timestamp();
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
		fb_filledcircle(x0, y0, tmp, color);
		i++;
		display_timestamp();
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
		fb_rectangle(x0, y0, x1, y1, color);
		i++;
		display_timestamp();
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
#if 0
		if (strcmp(&fnbuf[l - 4], ".RAW") != 0 &&
		    strcmp(&fnbuf[l - 4], ".raw") != 0)
#else
		if (strcmp(&fnbuf[l - 4], ".JPG") != 0 &&
		    strcmp(&fnbuf[l - 4], ".jpg") != 0)
#endif
			continue;

if (0)
		load_raw(fnbuf);
else
		load_jpg(fnbuf);

		RDTSC(start);
		do {
			fb_text(16, 264, fnbuf, fb_rgb2pal(255, 255, 255), 0);
			display_timestamp();
			res = sio_getchar(0);
			if (res == ' ')
				goto switch_mode;
			RDTSC(tmp);
		} while (res != ' ' && tmp - start < freq_khz * 5000);
	}
#endif
}
