/*-
 * Copyright (c) 2013 - 2015 Marko Zec
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
#include <stdio.h>
#include <string.h>

#ifdef f32c
#include <fatfs/ff.h>
#include <dev/io.h>
#else
#include <sys/stat.h>
#include <dirent.h>
#endif

#include "bas.h"


int
file_cd()
{
	char name[128];
	STR st;
	int start = 0;
#ifdef f32c
	int fres;
	char buf[4];
	FF_DIR dir;
#endif

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(name, st->strval);
	FREE_STR(st);
	check();

#ifdef f32c
	if (strlen(name) >= 2 && name[1] == ':') {
		buf[0] = name[0];
		buf[1] = ':';
		buf[2] = 0;

		/* Open the directory */
		fres = f_opendir(&dir, buf);
		if (fres != FR_OK)
			error(15);
		if (f_chdrive(buf) != FR_OK)
			error(15);
		start = 2;
	}

	if (strlen(name) > start && f_chdir(&name[start]) != FR_OK)
		error(15);
#else
	if (chdir(&name[start]))
		error(15);
#endif
	normret;
}


STR
bdirs()
{
	char *name;
	STR st;
	int len;
#ifdef f32c
	FF_DIR dir;
	FILINFO finfo;
	int fres;
#else
	DIR *dir;
	struct dirent *dp;
#endif

	st = stringeval();
	NULL_TERMINATE(st);

#ifdef f32c
	bzero(&dir, sizeof(dir));
	bzero(&finfo, sizeof(finfo));
	fres = f_opendir(&dir, st->strval);
	if (fres != FR_OK) {
		FREE_STR(st);
		error(15);
	}
#else
	dir = opendir(st->strval);
	if (dir == NULL) {
		FREE_STR(st);
		error(15);
	}
#endif

	st->strlen = 0;
#ifdef f32c
	while (f_readdir(&dir, &finfo) == FR_OK && finfo.fname[0] != 0) {
		name = finfo.fname;
#else
	while ((dp = readdir(dir)) != NULL) {
		name = dp->d_name;
#endif
		len = strlen(name);
		if (st->alloclen < st->strlen + len + 1)
			RESERVE_SPACE(st, st->strlen + len + 1);
		if (st->strlen != 0) {
			st->strval[st->strlen] = ' ';
			st->strlen++;
		}
		strcpy(&st->strval[st->strlen], name);
		st->strlen += len;
	}
#ifndef f32c
	closedir(dir);
#endif
	return(st);
}


int
file_pwd()
{
	char buf[256];

	check();
#ifdef f32c
	f_getcwd(buf, 256);
#else
	getcwd(buf, 256);
#endif
	printf("%s\n", buf);
	normret;
}


int
file_kill()
{
	char name[128];
	STR st;

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(name, st->strval);
	FREE_STR(st);
	check();
#ifdef f32c
	if (f_unlink(name) != FR_OK)
		error(15);
#else
	if (unlink(name))
		error(15);
#endif
	normret;
}


int
file_mkdir()
{
	char name[128];
	STR st;

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(name, st->strval);
	FREE_STR(st);
	check();
#ifdef f32c
	if (f_mkdir(name) != FR_OK)
		error(15);
#else
	if (mkdir(name, 0777))
		error(15);
#endif
	normret;
}


int
file_copy()
{
	char from_name[128], to_name[128];
	char *buf;
	int buflen;
	STR st;
	int from, to;
	int got, wrote;
	int tot = 0;
#ifdef f32c
	uint32_t start, end;
#endif

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(from_name, st->strval);
	FREE_STR(st);
	if(getch() != ',')
		error(SYNTAX);

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(to_name, st->strval);
	FREE_STR(st);
	check();

	from = open(from_name, O_RDONLY);
	if (from < 0)
		error(15);

	for (buflen = 64 * 1024; buflen >= 4096; buflen = buflen >> 1) {
		buf = mmalloc(buflen);
		if (buf != NULL)
			break;
	}
	if (buf == NULL) {
		close (from);
		error(24);	/* out of core */
	}

	to = open(to_name, O_CREAT|O_RDWR, 0);
	if (to < 0) {
		mfree(buf);
		close (from);	/* cannot creat file */
		error(14);
	}

#ifdef f32c
	RDTSC(start);
#endif
	do {
		got = read(from, buf, buflen);
		if (got < 0) {
			close(from);
			close(to);
			mfree(buf);
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
#ifdef f32c
		/* CTRL + C ? */
		if (sio_getchar(0) == 3) {
			printf("^C - interrupted!\n");
			got = 0;
		}
#endif
	} while (got > 0);
#ifdef f32c
	RDTSC(end);
#endif

	close(from);
	close(to);
	mfree(buf);
#ifdef f32c
	printf("Copied %d bytes in %f s (%f bytes/s)\n", tot,
	    0.001 * (end - start) / freq_khz,
	    tot / (0.001 * (end - start) / freq_khz));
#else
	printf("Copied %d bytes\n", tot);
#endif

	normret;
}


int
file_rename()
{
	char from_name[128], to_name[128];
	STR st;

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(from_name, st->strval);
	FREE_STR(st);
	if(getch() != ',')
		error(SYNTAX);

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(to_name, st->strval);
	FREE_STR(st);
	check();

#ifdef f32c
	if (f_rename(from_name, to_name) != FR_OK)
		error(15);
#else
	if (rename(from_name, to_name))
		error(15);
#endif
	normret;
}


int
file_more()
{
	char buf[128];
	STR st;
#ifdef f32c
	int fd, got, i, c, last, lno = 0;
#endif

	st = stringeval();
	NULL_TERMINATE(st);
#ifdef f32c
	strcpy(buf, st->strval);
#else
	sprintf(buf, "more %s", st->strval);
#endif
	FREE_STR(st);
	check();

#ifndef f32c
	do_system(buf);
#else
	fd = open(buf, 0);
	if (fd < 0)
		error(15);

	do {
		got = read(fd, buf, 128);
		for (i = 0, last = 0; i < got; i++) {
			if (buf[i] == '\n') {
				write(1, &buf[last], i - last + 1);
				last = i + 1;
				lno++;
				if (lno == 23) {
stopped:
					printf("-- more --");
					c = sio_getchar(1);
					printf("\r          \r");
					switch(c) {
					case 3:
						printf("^C\n");
					case 4:
					case 'q':
						goto done;
					case ' ':
						lno = 0;
						break;
					case '\r':
					case 'j':
						lno--;
						break;
					default:
						goto stopped;
					}
				}
			}
		}
		write(1, &buf[last], i - last);
	} while (got > 0);

done:
	close(fd);
#endif
	normret;
}
