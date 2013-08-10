/*
 * Glue between POSIX unistd open etc. and FatFS interfaces.
 */

#include <sys/param.h>

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

#include <fatfs/ff.h>

#define MAXFILES 32


static int max_open = -1;
static struct {
	FIL 	fp;
	int	in_use;
} file_map[MAXFILES];


int
open(const char *path, int flags __unused, ...)
{
	int d;

	if (max_open == MAXFILES - 2)
		return (-1);
	for (d = 0; d <= max_open; d++)
		if (file_map[d].in_use)
			break;
	if (d == max_open)
		d++;

	/* XXX temp. hack - revisit flag mapping!!! */
	if (f_open(&file_map[d].fp, path, FA_READ))
		return (-1);

	if (d > max_open)
		max_open = d;
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

	if (d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);
	f_close(&file_map[d].fp);
	file_map[d].in_use = 0;
	return (0);
}


ssize_t
read(int d, void *buf, size_t nbytes)
{
	FRESULT f_res;
	uint32_t got;

	if (d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);

	f_res = f_read(&file_map[d].fp, buf, nbytes, &got);
	if (f_res != FR_OK)
		return (-1);
	return (got);
}


ssize_t
write(int d, const void *buf, size_t nbytes)
{
	FRESULT f_res;
	uint32_t wrote;

	if (d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);

	f_res = f_write(&file_map[d].fp, buf, nbytes, &wrote);
	if (f_res != FR_OK)
		return (-1);
	return (wrote);
}


off_t
lseek(int d, off_t offset, int whence)
{
	FRESULT f_res;

	if (d >= MAXFILES || file_map[d].in_use == 0)
		return (-1);

	/* XXX revisit!!! */
#define	SEEK_SET 0
	if (whence != SEEK_SET)
		return (-1);

	f_res = f_lseek(&file_map[d].fp, offset);
	if (f_res != FR_OK)
		return (-1);
	return (offset);
}


int
unlink(const char *path)
{
	FRESULT f_res;

	f_res = f_unlink(path);
	if (f_res != FR_OK)
		return (-1);
	return (0);
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

