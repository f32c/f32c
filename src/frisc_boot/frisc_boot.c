/*
 * Load xconas-formatted FRISC code in memory, and start the FRISC core.
 *
 * $Id$
 */

#include <ctype.h>
#include <fcntl.h>
#include <io.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fatfs/ff.h>


static const char *drive = "d:";


static void
try_boot(char *fname)
{
	int fno;
	char *cp = NULL;
	void *bootaddr = (void *) -1;
	int val = 0, pos = 0;
	char c, x;
	char buf[128];

	sprintf(buf, "%s%s", drive, fname);
	fno = open(buf, O_RDONLY);
	if (fno < 0)
		return;

	printf("Loading %s\n", buf);
	while (read(fno, &c, 1) == 1) {
		if (!isascii(c))
			return;
		if (c < ' ') {
			pos = 0;
			val = (int) cp;
			continue;
		}
		pos++;
		if (c >= '0' && c <= '9')
			x = c - '0';
		else if (c >= 'A' && c <= 'F')
			x = c - 'A' + 10;
		else if (c >= 'a' && c <= 'f')
			x = c - 'a' + 10;
		else
			continue;
		val <<= 4;
		val += x;
		if (pos == 8) {
			cp = (void *) val;
			if (bootaddr == (void *) -1)
				bootaddr = cp;
			val = 0;
			continue;
		}
		if (pos == 12 || pos == 15 || pos == 18 || pos == 21)
			*cp++ = val;
	}
	if (bootaddr != (void *) -1) {
		*((int *) 0x3ffc) = (int) bootaddr;
		OUTB(IO_CPU_RESET + 0xc, 1);
	}
}


void
main(void)
{
	FRESULT fres;
	FILINFO fno;
	DIR dir;
	static char lfn[_MAX_LFN + 1];
	char *fname;
	int l;

	fno.lfname = lfn;
	fno.lfsize = sizeof(lfn);

	/* Dummy open to force-mount MicroSD drive */
	l = open(drive, O_RDONLY);
	close(l);

	fres = f_opendir(&dir, drive);
	if (fres != FR_OK)
		OUTB(IO_CPU_RESET + 0xc, 1);

        do {
		/* Read a directory item */
		fres = f_readdir(&dir, &fno);
		if (fres != FR_OK || fno.fname[0] == 0)
			break;
		if (lfn[0] == 0)
			fname = fno.fname;
		else
			fname = lfn;
		l = strlen(fname);
		if (l > 2 && strcmp(&fname[l - 2], ".p") == 0)
			try_boot(fname);
	} while (1);
	OUTB(IO_CPU_RESET + 0xc, 1);
}
