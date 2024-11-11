/*
 * Play WAV files stored on a MicroSD card.
 */

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dev/io.h>
#include <dev/lcd.h>

#include <fatfs/ff.h>


#define	MAX_FNAMES	256

char **fnames;
int fcnt;


void
scan_files(char* path)
{
	FRESULT res;
	FILINFO fno;
	FF_DIR dir;
	int i, t;

	/* Open the directory */
	res = f_opendir(&dir, path);
	if (res != FR_OK)
		return;

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
		path[i] = '/';
		strcpy(&path[i+1], fno.fname);
		if (fno.fattrib & AM_DIR)
			scan_files(path);
		else {
			t = strlen(path);
			if (t > 4 && strcmp(&path[t - 4], ".WAV") == 0)
				strcpy(fnames[fcnt++], path);
		}
		path[i] = 0;
	} while (1);
}


void
main(void)
{
	char tmpbuf[256];
	int i, f, fpos = 0, block, cur, got, vol = 0xfff;
	char *buf = (void *) 0x80080000;

	fnames = malloc(MAX_FNAMES * 256);

	tmpbuf[0] = 'd';
	tmpbuf[1] = ':';
	tmpbuf[2] = 0;
	f = open(tmpbuf, O_RDONLY);
	if (f > 0)
		close(f);
	scan_files(tmpbuf);
	lcd_init();

next_file:
	f = open(fnames[fpos], O_RDONLY);
	if (f < 0) {
		printf("Open failed\n");
		exit (1);
	}
	printf("Playing %s, vol %d\n", fnames[fpos], vol);
	lcd_pos(0, 0);
	lcd_puts(&fnames[fpos][3]);
	lcd_puts("          ");

	block = 0;
	got = read(f, buf, 0x8000);
	OUTW(IO_PCM_FIRST, buf);
	OUTW(IO_PCM_LAST, buf + 0x7ffe);
	OUTW(IO_PCM_FREQ, 9108); /* 44.1 kHz sample rate */
	OUTW(IO_PCM_VOLUME, vol + (vol << 16));

	while (got > 0) {
		INW(cur, IO_PCM_CUR);
		if ((cur & 0x4000) != block) {
			got = read(f, buf + block, 0x4000);
			block = cur & 0x4000;
			INB(i, IO_PUSHBTN);
			if ((i & BTN_UP) && vol < 0xffff)
				vol = (vol << 1) + 1;
			if ((i & BTN_DOWN) && vol > 0)
				vol = vol >> 1;
			if ((i & (BTN_UP|BTN_DOWN)))
				printf("Playing %s, vol %d\n",
				    fnames[fpos], vol);
			lcd_pos(0, 1);
			sprintf(tmpbuf, "volume %d ", vol);
			lcd_puts(tmpbuf);
			OUTW(IO_PCM_VOLUME, vol + (vol << 16));
			if ((i & BTN_LEFT)) {
				close(f);
				if (fpos == 0)
					fpos = fcnt;
				fpos--;
				goto next_file;
			}
			if ((i & BTN_RIGHT))
				break;
		}
#ifdef __mips__
		/* Wait for an interrupt, but which one? - XXX REVISIT!!! */
		__asm __volatile__("wait");
#endif
	}
	close(f);
	fpos++;
	if (fpos == fcnt)
		fpos = 0;
	goto next_file;
}
