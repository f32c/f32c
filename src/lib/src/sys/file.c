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
#include <sys/stat.h>

/* XXX move to a .h ? */
extern int ff_open(struct file *fp, const char *path, int flags, ...);


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


static struct file *
fd2fp(int fd)
{
	struct task *ts = TD_TASK(curthread);
	struct file *fp = NULL;

	if (fd < 0 || fd >= ts->ts_maxfiles ||
	    (fp = (struct file *) ts->ts_files[fd]) == NULL)
		errno = EBADF;

	return (fp);
}


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


int
close(int fd)
{
	struct task *ts = TD_TASK(curthread);
	struct file *fp = fd2fp(fd);
	int res;

	if (fp == NULL)
		return (-1);

	ts->ts_files[fd] = NULL;
	if (--(fp->f_refc))
		return (0);

	/* XXX temporary hack for stdin, stdout, stderr */
	if ((fp->f_mflags & F_MF_FILE_MALLOCED) == 0)
		return (0);

	res = fp->f_ops->fo_close(fp);
	free(fp->f_priv);
	free(fp);
	return (res);
}


ssize_t
read(int fd, void *buf, size_t nbytes)
{
	struct file *fp = fd2fp(fd);
	ssize_t got = 0;

	if (fp == NULL)
		return (-1);

	/* XXX temporary hack for stdin, stdout, stderr */
	if (fd >= 0 && fd <= 2) {
		char *cp = (char *) buf;
		for (; nbytes != 0; nbytes--) {
			*cp++ = getchar() & 0177;
			got++;
		}
		return (got);
	}

	got = fp->f_ops->fo_read(fp, buf, nbytes);
	return (got);
}


ssize_t
write(int fd, const void *buf, size_t nbytes)
{
	struct file *fp = fd2fp(fd);
	ssize_t wrote = nbytes;

	if (fp == NULL)
		return (-1);

	wrote = fp->f_ops->fo_write(fp, buf, nbytes);
	return (wrote);
}


/* Entirely unimplemented, just empty placeholders */

int
fcntl(int fd __unused, int cmd __unused, ...)
{

	return (-1);
}


int
stat(const char *path __unused, struct stat *sb __unused)
{

	return (-1);
}


int
fstat(int fd __unused, struct stat *sb __unused)
{

	return (-1);
}


int
fputc(int c, FILE *fp)
{
	char b = c;
	int res;

	res = write(fp->_fd, &b, 1);
	if (res != 1)
		return (EOF);

	return (c);
}


int
putchar(int c)
{

	return (fputc(c, stdout));
}


int
fputs(const char *str, FILE *fp)
{
	int len = strlen(str);
	int res;

	res = write(fp->_fd, str, len);
	if (res != len)
		return (EOF);

	return (len);
}


int
puts(const char *str)
{

	return (fputs(str, stdout));
}
