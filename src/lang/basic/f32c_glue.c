/*-
 * Copyright (c) 2013, 2014 Marko Zec
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
 */

#include <fcntl.h>
#include <setjmp.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include <dev/io.h>
#include <dev/sio.h>
#include <dev/lcd.h>
#include <sys/isr.h>
#include <fatfs/ff.h>
#include <mips/asm.h>

#include "bas.h"


int _errno;
uint32_t freq_khz, tsc_hi, tsc_lo;


static int
tsc_update(void)
{
	uint32_t tsc;

	/* Clear the vertical video blank interrupt (50-60 Hz) */
	INW(tsc, IO_FB);
	INW(tsc, IO_C2VIDEO_BASE);

	RDTSC(tsc);
	if (tsc < tsc_lo)
		tsc_hi++;
	tsc_lo = tsc;
	return (1);
}


static struct isr_link fb_isr = {
	.handler_fn = &tsc_update
};


void
setup_f32c(void)
{

	freq_khz = (get_cpu_freq() + 499) / 1000;
#ifdef __mips__
	isr_register_handler(2, &fb_isr);
	__asm("ei");
#else
	fb_isr.handler_fn();
#endif
}


#undef memcpy
void *
memcpy(void *dst, const void *src, size_t len)
{
	const char *from = src;
	char *to = dst;

	for(; len != 0; len--)
		*to++ = *from++;
	return (dst);
}


char *
getenv(const char *name)
{

	if (strcmp(name, "TERM") == 0)
		return ("ansi");	/* for CLS */
	return ("");
}

pid_t
getpid(void)
{

	return (0);
}


int
kill(pid_t pid __unused, int sig __unused)
{

	return (-1);
}


sig_t
signal(int sig, sig_t func)
{

	return (SIG_ERR);
}


void
_exit(int status)
{

	do {
		exit (status);
	} while (1);
}


int
syscall(int number __unused, ...)
{

	return (-1);
}


static struct tm t;

struct tm *
localtime(const time_t *clock __unused)
{

printf("XXXX %s()\n", __FUNCTION__);
	return (&t);
}


char *
ctime(const time_t *clock __unused)
{

printf("XXXX %s()\n", __FUNCTION__);
	return ("");
}


void
srand(unsigned seed __unused)
{

printf("XXXX %s()\n", __FUNCTION__);
}


void
__assert(const char *func, const char *file, int lno, const char *expr)
{

	printf("assert failed: file %s line %d function %s expr %s\n",
	    file, lno, func, expr);
	while (1) {
		exit(1);
	}
}


static int scan_line;
static int scan_stop;


static int
do_ls(const char *path)
{
	FRESULT fres;
	FILINFO fno;
	FATFS *fs;
	FF_DIR dir;
	DWORD free_clust;
	int c, filecnt = 0;
	uint64_t totsize = 0;
	char *fname;

	/* Open the directory */
	bzero(&dir, sizeof(dir));
	bzero(&fno, sizeof(fno));
	fres = f_opendir(&dir, path);
	if (fres != FR_OK)
		return (fres);
	printf("Directory for %s\n", path);

	do {
		/* Read a directory item */
		fres = f_readdir(&dir, &fno);
		if (fres != FR_OK || fno.fname[0] == 0)
			break;
		fname = fno.fname;
		if (fno.fattrib & AM_DIR)
			printf("<DIR>       %s\n", fname);
		else {
			printf("%10d  %s\n", (int) fno.fsize, fname);
			totsize += fno.fsize;
		}
		filecnt++;

		/* Pager */
		if (scan_line++ >= scan_stop) {
			printf("--More-- (line %d)", scan_line);
			c = getchar();
			printf("\r                      \r");
			if (c == 3 || c == 'q')
				return (fres);
			scan_stop = scan_line;
			if (c == ' ')
				scan_stop += 21;
		}
	} while (1);

	if (f_getfree(path, &free_clust, &fs))
		return (-1);
	printf("%u Kbytes in %d files, ",
	    (uint32_t) (totsize / 1024), filecnt);
	printf("%u Kbytes free.\n",
	    free_clust * fs->csize * (fs->ssize / 512) / 2);

	return (fres);
}


int
do_system(char *cp)
{

	scan_line = 0;
	scan_stop = 21;

	if (strlen(cp) >= 5 && strncmp(cp, "ls -", 4) == 0) {
		for (cp = &cp[5]; *cp == ' '; cp++)
			{}
		return(do_ls(cp));
	}

printf("XXX do_system: _%s_\n", cp);
	return (-1);
}


static char ir_red, ir_blue;

int
lego_ch(void)
{
	int ch;

	ch = evalint();
	check();
	if (ch < 0 || ch > 4)
		error(33);
	if (ch > 0)
		ch += 127;
	ir_red = ir_blue = 0;
        OUTB(IO_LEGO_CTL, ch);
        OUTB(IO_LEGO_DATA, 0);
	normret;
}


int
lego_red(void)
{
	int val;

	val = evalint();
	check();
	if (val < -7 || val > 7)
		error(33);
	ir_red = val;
        OUTB(IO_LEGO_DATA, (ir_blue << 4) | (ir_red & 0xf));
	normret;
}


int
lego_blue(void)
{
	int val;

	val = evalint();
	check();
	if (val < -7 || val > 7)
		error(33);
	ir_blue = val;
        OUTB(IO_LEGO_DATA, (ir_blue << 4) | (ir_red & 0xf));
	normret;
}


int
b_lcd_init(void)
{

	check();
	lcd_init();
	normret;
}


int
b_lcd_puts(void)
{
	STR st;
	int c;

	st = stringeval();
	c = getch();

	if (istermin(c))
		point--;
	else {
		FREE_STR(st);
		error(SYNTAX);
	}

	NULL_TERMINATE(st);
	lcd_puts(st->strval);
	FREE_STR(st);
	normret;
}


int
b_lcd_pos(void)
{
	int x, y;

	x = evalint();
	if (getch() != ',')
		error(SYNTAX);
	y = evalint();
	check();
	if (x < 0 || x > 15 || y < 0 || y > 1)
		error(BADDATA);
	lcd_pos(x, y);
	normret;
}
