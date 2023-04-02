/*
 * Play WAV files stored on a MicroSD card.
 *
 * $Id$
 */

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <fatfs/ff.h>


void
scan_files(char* path)
{
	FRESULT res;
	FILINFO fno;
	DIR dir;
	int i;

	/* Open the directory */
	res = f_opendir(&dir, path);
	if (res != FR_OK)
		return;

	i = strlen(path);
	do {
		/* Read a directory item */
		res = f_readdir(&dir, &fno);
		if (res != FR_OK || fno.fname[0] == 0)
			break;

		/* Ignore dot entry */
		if (fno.fname[0] == '.')
			continue;

		/* Recursively scan subdirectories */
		path[i] = '/';
		strcpy(&path[i+1], fno.fname);
		if (fno.fattrib & AM_DIR)
			scan_files(path);
		else
			printf("%s\n", path);
		path[i] = 0;
	} while (1);
}


void
main(void)
{
	char tmpbuf[128];
	int f;

	tmpbuf[0] = 'd';
	tmpbuf[1] = ':';
	tmpbuf[2] = 0;
	f = open(tmpbuf, O_RDONLY);
	if (f > 0)
		close(f);
	scan_files(tmpbuf);
}
