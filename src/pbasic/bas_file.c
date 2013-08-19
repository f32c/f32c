
#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <fatfs/ff.h>

#include "bas.h"


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


int
file_copy()
{
	char buf[4096];
	STR st1, st2;
	int from, to;
	int got, wrote;
	int tot = 0;

	st1 = stringeval();
	NULL_TERMINATE(st1);
	if(getch() != ',')
		error(SYNTAX);
	st2 = stringeval();
	NULL_TERMINATE(st2);
	check();

	from = open(st1->strval, O_RDONLY);
	FREE_STR(st1);
	if (from < 0)
		error(15);
	to = open(st2->strval, O_CREAT|O_RDWR);
	FREE_STR(st2);
	if (to < 0) {
		close (from);
		error(14);
	}

	do {
		got = read(from, buf, sizeof(buf));
		if (got < 0) {
			close(from);
			close(to);
			error(30);	/* unexpected eof */
		}
		wrote = write(to, buf, got);
		if (wrote < got) {
			close(from);
			close(to);
			error(60);	/* File write error */
		}
		tot += wrote;
	} while (got > 0);

	close(from);
	close(to);
	printf("Copied %d bytes.\n", tot);
	normret;
}


int
file_rename()
{
	STR st1, st2;

	st1 = stringeval();
	NULL_TERMINATE(st1);
	if(getch() != ',')
		error(SYNTAX);
	st2 = stringeval();
	NULL_TERMINATE(st2);
	check();
	if (f_rename(st1->strval, st2->strval) != FR_OK)
		goto fail;
	FREE_STR(st1);
	FREE_STR(st2);
	goto ok;
fail:
	FREE_STR(st1);
	FREE_STR(st2);
	error(15);
ok:
	normret;
}
