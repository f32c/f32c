/*-
 * Copyright (c) 2013 Marko Zec
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
 *
 * $Id$
 */

#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <fatfs/ff.h>

#include <io.h>

#include "bas.h"


#ifdef OWN_ALLOC
extern void *m_get(unsigned int);
extern void m_free(void *);
#else
#define	m_get(size) malloc(size)
#define	m_free(ptr) free(ptr)
#endif


int
file_cd()
{
	char name[128];
	STR st;
	DIR dir;
	int fres;
	int start = 0;
	char buf[4];

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(name, st->strval);
	FREE_STR(st);
	check();

	if (strlen(name) >= 2 && name[1] == ':') {
		buf[0] = name[0];
		buf[1] = ':';
		buf[2] = 0;
		if (buf[0] < '0' || buf[0] > '1')
			error(15);

		/* Dummy open, just to auto-mount the volume */
		fres = open(buf, 0);
		if (fres >= 0)
			close(fres);

		/* Open the directory */
		fres = f_opendir(&dir, buf);
		if (fres != FR_OK)
			error(15);
		if (f_chdrive(buf[0] - '0') != FR_OK)
			error(15);
		start = 2;
	}

	if (strlen(name) > start && f_chdir(&name[start]) != FR_OK)
		error(15);
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
	char name[128];
	STR st;

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(name, st->strval);
	FREE_STR(st);
	check();
	if (f_unlink(name) != FR_OK)
		error(15);
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
	if (f_mkdir(name) != FR_OK)
		error(15);
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
	uint32_t start, end;

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
		buf = m_get(buflen);
		if (buf != NULL)
			break;
	}
	if (buf == NULL) {
		close (from);
		error(24);	/* out of core */
	}

	to = open(to_name, O_CREAT|O_RDWR);
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
		/* CTRL + C ? */
		if (sio_getchar(0) == 3) {
			printf("^C - interrupted!\n");
			got = 0;
		}
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

	if (f_rename(from_name, to_name) != FR_OK)
		error(15);
	normret;
}


int
file_more()
{
	char buf[128];
	STR st;
	int fd, got, i, c, last, lno = 0;

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(buf, st->strval);
	FREE_STR(st);
	check();

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
	normret;
}
