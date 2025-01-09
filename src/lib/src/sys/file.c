/*-
 * Copyright (c) 2013 - 2025 Marko Zec
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/file.h>
#include <sys/task.h>


static int
fd_findfree(int min)
{
	struct task *ts = TD_TASK(curthread);
	int fd, nfds;

	nfds = ts->ts_maxfiles;
	for (fd = min; fd < nfds; fd++)
		if (ts->ts_files[fd] == NULL)
			break;
	if (fd < nfds)
		return (fd);
	return (-1);
}


static int
fd_alloc(void)
{
	struct task *ts = TD_TASK(curthread);
	struct file **new_ts_files;
	int fd, nfds;

	fd = fd_findfree(0);
	if (fd >= 0)
		return (fd);

	/* Expand the file descriptor table */
	fd = ts->ts_maxfiles;
	nfds = 2 * fd;
	new_ts_files = (struct file **) calloc(nfds, sizeof(struct file *));
	if (new_ts_files == NULL)
		return (-1);
	memcpy(new_ts_files, ts->ts_files, fd * sizeof(struct file *));
	if (fd > 3)
		free(ts->ts_files);
	ts->ts_files = new_ts_files;
	ts->ts_maxfiles = nfds;
	
	return (fd);
}


extern int ff_open(struct file *fp, const char *path, int flags, ...);

int
open(const char *path, int flags, ...)
{
	struct task *ts = TD_TASK(curthread);
	struct file *fp;
	int fd;

	fd = fd_alloc();
	fp = calloc(1, sizeof(struct file));
	if (fd < 0 || fp == NULL) {
		free(fp);
		errno = ENFILE;
		return (fd);
	}

	ts->ts_files[fd] = fp;
	fp->f_mflags = F_MF_FILE_MALLOCED | F_MF_PRIV_MALLOCED;
	fp->f_refc = 1;

	if (ff_open(fp, path, flags) == 0)
		return (fd);

	ts->ts_files[fd] = NULL;
	free(fp->f_priv);
	free(fp);
	return (-1);
}
