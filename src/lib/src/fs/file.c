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

/*
 * Glue between POSIX unistd open etc. and FatFS interfaces.
 */

#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>

#include <fatfs/diskio.h>

#include <dev/io.h>


#define MAXFILES 8


static FATFS *ff_mounts[FF_VOLUMES];
static int ff_mounted;

static FIL *file_map[MAXFILES];


static int
ffres2errno(int fferr)
{

	switch(fferr) {
	case FR_OK:
		return 0;
	case FR_DISK_ERR:
	case FR_INT_ERR:
	case FR_NOT_READY:
		errno = EIO;
		break;
	case FR_NO_FILE:
	case FR_NO_PATH:
		errno = ENOENT;
		break;
	case FR_INVALID_NAME:
		errno = ENAMETOOLONG;
		break;
	case FR_DENIED:
		errno = EACCES;
		break;
	case FR_EXIST:
		errno = EEXIST;
		break;
	case FR_WRITE_PROTECTED:
		errno = EROFS;
		break;
	case FR_INVALID_PARAMETER:
		errno = EINVAL;
		break;
	case FR_INVALID_OBJECT:
	case FR_INVALID_DRIVE:
	case FR_NOT_ENABLED:
	case FR_NO_FILESYSTEM:
	case FR_MKFS_ABORTED:
	case FR_TIMEOUT:
	case FR_LOCKED:
	case FR_NOT_ENOUGH_CORE:
	case FR_TOO_MANY_OPEN_FILES:
		/* XXX TODO resolve the above */
	default:
		errno = EOPNOTSUPP;
	}
	return -1;
}


static struct diskio_inst disk_i[FF_VOLUMES] = {
	{ .prefix = "C:" },
	{ .prefix = "D:" },
	{ .prefix = "F:" },
	{ .prefix = "R:" }
};


static void
check_automount(void)
{
	int i;

	if (ff_mounted)
		return;

	for (i = 0; i < FF_VOLUMES; i++) {
		if (ff_mounts[i] != NULL)
			continue;
		ff_mounts[i] = malloc(sizeof(FATFS));
		if (ff_mounts[i] == NULL)
			return;
		if (i == 0)
			diskio_attach_flash(&disk_i[i],
			    IO_SPI_FLASH, /* SPI port */
			    0, /* SPI slave unit */
			    1024 * 1024, /* offset from media start, bytes*/
			    3 * 1024 * 1024 /* block size, bytes*/);
		else
			diskio_attach_ram(&disk_i[i],
			    malloc(i * 1024 * 1024), /* base addr*/
			    i * 1024 * 1024 /* size, bytes */);
		f_mount(ff_mounts[i], disk_i[i].prefix, 0);
	}
	ff_mounted = 1;
}


int
open(const char *path, int flags, ...)
{
	int d, res;
	int ff_flags;

	check_automount();

	for (d = 0; d < MAXFILES; d++)
		if (file_map[d] == NULL)
			break;
	if (d == MAXFILES) {
		errno = ENFILE;
		return (-1);
	}

	/* Map open() flags to f_open() flags */
	ff_flags = ((flags & O_ACCMODE) + 1);
#if !defined(_FS_READONLY) || (_FS_READONLY == 0)
	if (flags & (O_CREAT | O_TRUNC))
		ff_flags |= FA_CREATE_ALWAYS;
	else if (flags & O_CREAT)
		ff_flags |= FA_OPEN_ALWAYS;
#endif

	file_map[d] = malloc(sizeof(FIL));
	if (file_map[d] == NULL) {
		errno = ENOMEM;
		return (-1);
	}

	res = f_open(file_map[d], path, ff_flags);
	if (res != FR_OK) {
		free(file_map[d]);
		file_map[d] = NULL;
		return(ffres2errno(res));
	}

	return (d + 3);
}


int
creat(const char *path, mode_t mode __unused)
{

	check_automount();
	return (open(path, O_CREAT | O_TRUNC | O_WRONLY));
}


int
close(int d)
{
	int res;

	/* XXX hack for stdin, stdout, stderr */
	if (d >= 0 && d <= 2)
		return (0);
	d -= 3;

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL) {
		errno = EBADF;
		return (-1);
	}
	res = f_close(file_map[d]);
	free(file_map[d]);
	file_map[d] = NULL;
	return(ffres2errno(res));
}


ssize_t
read(int d, void *buf, size_t nbytes)
{
	FRESULT f_res;
	uint32_t got = 0;

	/* XXX hack for stdin, stdout, stderr */
	if (d >= 0 && d <= 2) {
		char *cp = (char *) buf;
		for (; nbytes != 0; nbytes--) {
			*cp++ = getchar() & 0177;
			got++;
		}
		return (got);
	}
	d -= 3;

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL) {
		errno = EBADF;
		return (-1);
	}

	f_res = f_read(file_map[d], buf, nbytes, &got);
	if (f_res != FR_OK)
		return(ffres2errno(f_res));
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

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL) {
		errno = EBADF;
		return (-1);
	}

#if defined(_FS_READONLY) && (_FS_READONLY == 1)
	return (-1);
#else
	f_res = f_write(file_map[d], buf, nbytes, &wrote);
	if (f_res != FR_OK)
		return(ffres2errno(f_res));
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

	if (d < 0 || d >= MAXFILES || file_map[d] == NULL) {
		errno = EBADF;
		return (-1);
	}

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
		errno = EINVAL;
		return (-1);
	}

	f_res = f_lseek(file_map[d], offset);
	if (f_res != FR_OK)
		return(ffres2errno(f_res));
	return ((int) f_tell(file_map[d]));
}


int
unlink(const char *path)
{
#if !defined(_FS_READONLY) || (_FS_READONLY == 0)
	FRESULT f_res;

	check_automount();
	f_res = f_unlink(path);
	return(ffres2errno(f_res));
#else
	return (-1);
#endif
}


int
chdir(const char *path) {
	int res;

	check_automount();
	if (path[1] == ':' && path[2] == 0)
		res = f_chdrive(path);
	else
		res = f_chdir(path);
	return(ffres2errno(res));
}


char *
getcwd(char *buf, size_t size)
{
	int res;

	check_automount();

	if (buf == NULL)
		buf = malloc(FF_MAX_LFN);

	if (buf == NULL) {
		errno = ENOMEM;
		return buf;
	}

	res = f_getcwd(buf, size);
	ffres2errno(res);
	return buf;
};


int
mkdir(const char *path, mode_t mode)
{
	int res;

	check_automount();
	res = f_mkdir(path);
	return(ffres2errno(res));
};


int
rmdir(const char *path)
{
	int res;

	check_automount();
	res = f_rmdir(path);
	return(ffres2errno(res));
};


int
rename(const char *from, const char *to)
{
	int res;

	check_automount();
	res = f_rename(from, to);
	return(ffres2errno(res));
};


DIR *
opendir(const char *path)
{
	int res;
	DIR *dirp = malloc(sizeof(DIR));

	if (dirp == NULL) {
		errno = EINVAL;
		return dirp;
	}

	res = f_opendir(&dirp->ff_dir, path);
	if (ffres2errno(res) != 0) {
		free(dirp);
		return NULL;
	}

	dirp->de.d_name = dirp->ff_info.fname;
	/* XXX TODO more ff_info to dirent translations */

	return dirp;
};


struct dirent *
readdir(DIR *dirp)
{
	int res;

	if (dirp == NULL) {
		errno = EINVAL;
		return NULL;
	}

	res = f_readdir(&dirp->ff_dir, &dirp->ff_info);
	if (ffres2errno(res) != 0 || dirp->ff_info.fname[0] == 0)
		return NULL;

	return &dirp->de;
};


int
closedir(DIR *dirp)
{
	int res;

	res = f_closedir(&dirp->ff_dir);
	free(dirp);
	return(ffres2errno(res));
};


/* Entirely unimplemented, just empty placeholders */

int
fcntl(int fd __unused, int cmd __unused, ...)
{

	check_automount();
	return (-1);
}


int
stat(const char *path __unused, struct stat *sb __unused)
{

	check_automount();
	return (-1);
}


int
fstat(int fd __unused, struct stat *sb __unused)
{

	check_automount();
	return (-1);
}
