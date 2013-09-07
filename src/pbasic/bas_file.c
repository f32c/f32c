
#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <fatfs/ff.h>

#include "bas.h"


extern void *m_get(unsigned int);
extern void m_free(void *);


int
file_cd()
{
	STR st;
	DIR dir;
	int fres;
	int start = 0;
	char buf[4];

	st = stringeval();
	NULL_TERMINATE(st);
	check();

	if (strlen(st->strval) >= 2 && st->strval[1] == ':') {
		buf[0] = st->strval[0];
		buf[1] = ':';
		buf[2] = 0;
		if (buf[0] < '0' || buf[0] > '1')
			goto fail;

		/* Dummy open, just to auto-mount the volume */
		fres = open(buf, 0);
		if (fres >= 0)
			close(fres);

		/* Open the directory */
		fres = f_opendir(&dir, buf);
		if (fres != FR_OK)
			goto fail;
		if (f_chdrive(buf[0] - '0') != FR_OK)
			goto fail;
		start = 2;
	}

	if (strlen(st->strval) > start && f_chdir(&st->strval[start]) != FR_OK)
		goto fail;
	FREE_STR(st);
	goto ok;
fail:
	FREE_STR(st);
	error(15);
ok:
	normret;
}


int
file_pwd()
{
	char buf[256];

	check();
	f_getcwd(buf, 256);
	printf("%s\n", buf);
	normret;
}


int
file_kill()
{
	STR st;

	st = stringeval();
	NULL_TERMINATE(st);
	check();
	if (f_unlink(st->strval) != FR_OK)
		goto fail;
	FREE_STR(st);
	goto ok;
fail:
	FREE_STR(st);
	error(15);
ok:
	normret;
}


int
file_mkdir()
{
	STR st;

	st = stringeval();
	NULL_TERMINATE(st);
	check();
	if (f_mkdir(st->strval) != FR_OK)
		goto fail;
	FREE_STR(st);
	goto ok;
fail:
	FREE_STR(st);
	error(15);
ok:
	normret;
}


#include <io.h>
#include <mips/asm.h>

int
file_copy()
{
	char nambuf[256];
	char *buf;
	int buflen;
	STR st1, st2;
	int from, to;
	int got, wrote;
	int tmp, tot = 0;
	uint32_t start, end, freq_khz;

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);

	st1 = stringeval();
	NULL_TERMINATE(st1);
	strcpy(nambuf, st1->strval);
	FREE_STR(st1);
	if(getch() != ',')
		error(SYNTAX);

	st2 = stringeval();
	NULL_TERMINATE(st2);
	check(); /* XXX st2 leak? */

	from = open(nambuf, O_RDONLY);
	if (from < 0)
		error(15);

	for (buflen = 64 * 1024; buflen >= 4096; buflen = buflen >> 1) {
		buf = m_get(buflen);
		if (buf != NULL)
			break;
	}
	if (buf == NULL) {
		close (from);
		FREE_STR(st2);
		error(24);	/* out of core */
	}

	to = open(st2->strval, O_CREAT|O_RDWR);
	FREE_STR(st2);
	if (to < 0) {
		m_free(buf);
		close (from);	/* cannot creat file */
		error(14);
	}

	RDTSC(start);
	do {
		got = read(from, buf, buflen);
		if (got < 0) {
			close(from);
			close(to);
			m_free(buf);
			error(30);	/* unexpected eof */
		}
		wrote = write(to, buf, got);
		if (wrote < got) {
			close(from);
			close(to);
			mfree(buf);
			error(60);	/* File write error */
		}
		tot += wrote;
	} while (got > 0);
	RDTSC(end);

	close(from);
	close(to);
	m_free(buf);
	printf("Copied %d bytes in %f s (%f bytes/s)\n", tot,
	    0.001 * (end - start) / freq_khz,
	    tot / (0.001 * (end - start) / freq_khz));

	normret;
}


int
file_rename()
{
	char buf[256];
	STR st1, st2;

	st1 = stringeval();
	NULL_TERMINATE(st1);
	strcpy(buf, st1->strval);
	FREE_STR(st1);
	if(getch() != ',')
		error(SYNTAX);

	st2 = stringeval();
	NULL_TERMINATE(st2);
	check();

	if (f_rename(buf, st2->strval) != FR_OK)
		goto fail;
	FREE_STR(st2);
	goto ok;
fail:
	FREE_STR(st2);
	error(15);
ok:
	normret;
}
