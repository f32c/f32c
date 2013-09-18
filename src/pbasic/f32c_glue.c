
#include <sys/param.h>

#include <fcntl.h>
#include <setjmp.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include <io.h>
#include <sio.h>
#include <fatfs/ff.h>
#include <mips/asm.h>

#include "bas.h"


extern int _end;

int errno;
uint32_t freq_khz, tsc_hi, tsc_lo;
static char *freep;


void
tsc_update(void)
{
	uint32_t tsc;

	RDTSC(tsc);
	if (tsc < tsc_lo)
		tsc_hi++;
	tsc_lo = tsc;
}


void
setup_f32c(void)
{
	uint32_t tmp;

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);
	sio_idle_fn = tsc_update;
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


void *sbrk(intptr_t p)
{

	/* First invocation.  Find out the first free address. */
	if (freep == NULL)
		freep = (void *) &_end;

	/* XXX hardcoded upper memory limit - revisit! */
	if ((void *) (freep + p) >= (void *) 0x800b0000)
		return ((void *) -1);

	freep = freep + p;
	return (freep);
}


int *__error(void)
{

	return (&errno);
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


time_t
time(time_t *tloc)
{
	time_t t = 0;

	if (tloc != NULL)
		*tloc = t;
	return (t);
}


static struct tm t;

struct tm *
localtime(const time_t *clock __unused)
{

	return (&t);
}


char *
ctime(const time_t *clock __unused)
{

	return ("");
}


void
srand(unsigned seed __unused)
{
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


/* XXX gcc -O3 yields an infinite loop (recursive jal memset): compiler bug? */
__attribute__((optimize("-O2")))
void *
memset(void *b, int c, size_t len)
{
	char *cp = b;
	int *ip = b;

	c &= 0xff;
	c |= (c << 8);
	c |= (c << 16);

	while (((int) cp & 3) && len-- > 0)
		*cp++ = c;
	for (;len >= 4; len -= 4)
		*ip++ = c;
	while (len-- > 0)
		*cp++ = c;

	return (b);
}


static int scan_line;
static int scan_stop;


static int
do_ls(const char *path)
{
	FRESULT fres;
	FILINFO fno;
	DIR dir;
	int c;
	char *fname;
	static char lfn[_MAX_LFN + 1];
	fno.lfname = lfn;
	fno.lfsize = sizeof(lfn);

	/* Dummy open, just to auto-mount the volume */
	fres = open(path, 0);
	if (fres >= 0)
		close (fres);

	/* Open the directory */
	fres = f_opendir(&dir, path);
	if (fres != FR_OK)
		return (fres);

	do {
		/* Read a directory item */
		fres = f_readdir(&dir, &fno);
		if (fres != FR_OK || fno.fname[0] == 0)
			break;

		if (fno.fattrib & AM_DIR)
			c = 'd';
		else
			c = ' ';
		if (lfn[0] == 0)
			fname = fno.fname;
		else
			fname = lfn;
		printf("%10d %c %s/%s\n", (int) fno.fsize, c, path, fname);

		/* Pager */
		if (scan_line++ >= scan_stop) {
			printf("--More-- (line %d)", scan_line);
			c = getchar();
			printf("\r                      \r");
			if (c == 3 || c == 'q')
				break;
			scan_stop = scan_line;
			if (c == ' ')
				scan_stop += 21;
		}
	} while (1);

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
