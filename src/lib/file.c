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

/*
 * Glue between POSIX unistd open etc. and FatFS interfaces.
 */

#include <sys/param.h>

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>

#include <fatfs/ff.h>

#define MAXFILES 8


static FATFS ff_mounts[2];
static int ff_mounted[2];

static struct {
	FIL 	fp;
	int	in_use;
} file_map[MAXFILES];


int
open(const char *path, int flags, ...)
{
	int try, d = 0;
	int ff_flags;
	DIR ff_dir;
	
	if (path[0] == '1' && path[1] == ':')
		d = 1;
	if (ff_mounted[d] == 0 && f_mount(d, &ff_mounts[d]) == FR_OK)
		for (try = 0; try <= d; try++)
			if (d == 0 || f_opendir(&ff_dir, "1:") == FR_OK) {
				ff_mounted[d] = 1;
				break;
			}
	if (ff_mounted[d] == 0)
		return (-1);

	/* XXX temp. hack - 0, 1 and 2 reserved for RS232 stdio */
	for (d = 3; d < MAXFILES; d++)
		if (file_map[d].in_use == 0)
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

	if (f_open(&file_map[d].fp, path, ff_flags))
		return (-1);

	file_map[d].in_use = 1;
	return (d);
}


int
creat(const char *path, mode_t mode __unused)
{

	return (open(path, O_CREAT | O_TRUNC | O_WRONLY));
}


int
close(int d)
{

	if (d < 0 || d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);
	f_close(&file_map[d].fp);
	file_map[d].in_use = 0;
	return (0);
}


ssize_t
read(int d, void *buf, size_t nbytes)
{
	FRESULT f_res;
	uint32_t got = 0;

	/* XXX hack */
	if (d >= 0 && d <= 2) {
		char *cp = (char *) buf;
		for (;nbytes != 0; nbytes--) {
			*cp++ = getchar() & 0177;
			got++;
		}
		return (got);
	}

	if (d < 0 || d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);

	f_res = f_read(&file_map[d].fp, buf, nbytes, &got);
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

	/* XXX hack */
	if (d >= 0 && d <= 2) {
		char *cp = (char *) buf;
		for (; nbytes != 0; nbytes--)
			printf("%c", *cp++);
		return (wrote);
	}

	if (d < 0 || d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);

#if defined(_FS_READONLY) && (_FS_READONLY == 1)
	return (-1);
#else
	f_res = f_write(&file_map[d].fp, buf, nbytes, &wrote);
	if (f_res != FR_OK)
		return (-1);
	return (wrote);
#endif
}


off_t
lseek(int d, off_t offset, int whence)
{
	FRESULT f_res;

	if (d < 0 || d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);

	switch (whence) {
	case SEEK_SET:
		break;
	case SEEK_CUR:
		offset = f_tell(&file_map[d].fp) + offset;
		break;
	case SEEK_END:
		offset = f_size(&file_map[d].fp) + offset; /* XXX revisit */
		break;
	default:
		return (-1);
	}

	f_res = f_lseek(&file_map[d].fp, offset);
	if (f_res != FR_OK)
		return (-1);
	return ((int) f_tell(&file_map[d].fp));
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

