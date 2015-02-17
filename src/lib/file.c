/*-
 * Copyright (c) 2013 - 2015 Marko Zec, University of Zagreb
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

/*
 * Glue between POSIX unistd open etc. and FatFS interfaces.
 */

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>

#include <fatfs/ff.h>

#define MAXFILES 8


static FATFS ff_mounts[2];
static char ff_mounted[2];

static FIL *file_map[MAXFILES];


int
open(const char *path, int flags, ...)
{
	int d;
	int ff_flags;
	
	if (ff_mounted[0] == 0) {
		f_mount(&ff_mounts[0], "C:", 0);
		ff_mounted[0] = 1;
	}
	if (ff_mounted[1] == 0) {
		f_mount(&ff_mounts[1], "D:", 0);
		ff_mounted[1] = 1;
	}

	for (d = 0; d < MAXFILES; d++)
		if (file_map[d] == NULL)
			break;
	if (d == MAXFILES)
		return (-1);

	/* Map open() flags to f_open() flags */
	ff_flags = ((flags & O_ACCMODE) + 1);
#if !defined(_FS_READONLY) || (_FS_READONLY == 0)
	if (flags & (O_CREAT | O_TRUNC))
		ff_flags |= FA_CREATE_ALWAYS;
	else if (flags & O_CREAT)
		ff_flags |= FA_OPEN_ALWAYS;
#endif

	file_map[d] = malloc(sizeof(FIL));
	if (file_map[d] == NULL)
		return (-1);

	if (f_open(file_map[d], path, ff_flags)) {
		free(file_map[d]);
		file_map[d] = NULL;
		return (-1);
	}

	return (d + 3);
}


int
creat(const char *path, mode_t mode __unused)
{

	return (open(path, O_CREAT | O_TRUNC | O_WRONLY));
}


int
close(int d)
{

	/* XXX hack for stdin, stdout, stderr */
	if (d >= 0 && d <= 2)
		return (0);
	d -= 3;

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL)
		return (-1);
	f_close(file_map[d]);
	free(file_map[d]);
	file_map[d] = NULL;
	return (0);
}


ssize_t
read(int d, void *buf, size_t nbytes)
{
	FRESULT f_res;
	uint32_t got = 0;

	/* XXX hack for stdin, stdout, stderr */
	if (d >= 0 && d <= 2) {
		char *cp = (char *) buf;
		for (;nbytes != 0; nbytes--) {
			*cp++ = getchar() & 0177;
			got++;
		}
		return (got);
	}
	d -= 3;

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL)
		return (-1);

	f_res = f_read(file_map[d], buf, nbytes, &got);
	if (f_res != FR_OK)
		return (-1);
	return (got);
}


ssize_t
write(int d, const void *buf, size_t nbytes)
{
#if !defined(_FS_READONLY) || (_FS_READONLY == 0)
	FRESULT f_res;
#endif
	uint32_t wrote = nbytes;

	/* XXX hack for stdin, stdout, stderr */
	if (d >= 0 && d <= 2) {
		char *cp = (char *) buf;
		for (; nbytes != 0; nbytes--)
			printf("%c", *cp++);
		return (wrote);
	}
	d -= 3;

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL)
		return (-1);

#if defined(_FS_READONLY) && (_FS_READONLY == 1)
	return (-1);
#else
	f_res = f_write(file_map[d], buf, nbytes, &wrote);
	if (f_res != FR_OK)
		return (-1);
	return (wrote);
#endif
}


off_t
lseek(int d, off_t offset, int whence)
{
	FRESULT f_res;

	/* XXX hack for stdin, stdout, stderr */
	if (d >= 0 && d <= 2)
		return (-1);
	d -= 3;

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL)
		return (-1);

	switch (whence) {
	case SEEK_SET:
		break;
	case SEEK_CUR:
		offset = f_tell(file_map[d]) + offset;
		break;
	case SEEK_END:
		offset = f_size(file_map[d]) + offset; /* XXX revisit */
		break;
	default:
		return (-1);
	}

	f_res = f_lseek(file_map[d], offset);
	if (f_res != FR_OK)
		return (-1);
	return ((int) f_tell(file_map[d]));
}


int
unlink(const char *path)
{
	FRESULT f_res;

#if !defined(_FS_READONLY) || (_FS_READONLY == 0)
	f_res = f_unlink(path);
	if (f_res != FR_OK)
		return (-1);
	return (0);
#else
	f_res = (path == path) - 2;	/* shut up unused arg warning */
	return (f_res);
#endif
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

