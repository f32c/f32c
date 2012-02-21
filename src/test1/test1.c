
#include <sys/param.h>
#include <sdcard.h>
#include <spi.h>
#include <stdio.h>
#include <string.h>

#include <fatfs/ff.h>


FATFS fh;


FRESULT
scan_files(char* path)
{
    FRESULT res;
    FILINFO fno;
    DIR dir;
    int i;
    char *fn;   /* This function is assuming non-Unicode cfg. */
#if _USE_LFN
    static char lfn[_MAX_LFN + 1];
    fno.lfname = lfn;
    fno.lfsize = sizeof(lfn);
#endif
    char *cp;


    res = f_opendir(&dir, path);	/* Open the directory */
    if (res == FR_OK) {
	i = strlen(path);
	for (;;) {
	    res = f_readdir(&dir, &fno); /* Read a directory item */
	    if (res != FR_OK || fno.fname[0] == 0) break;  /* Break on error or end of dir */
	    if (fno.fname[0] == '.') continue;	/* Ignore dot entry */
#if _USE_LFN
	    fn = *fno.lfname ? fno.lfname : fno.fname;
#else
	    fn = fno.fname;
#endif
	    if (fno.fattrib & AM_DIR) {	/* It is a directory */
#if 1
		cp = &path[i];
		*cp++ = '/';
		do {
		    *cp++ = *fn;
		} while (*fn++ != 0);
#else
		sprintf(&path[i], "/%s", fn);
#endif
		res = scan_files(path);
		if (res != FR_OK) break;
		path[i] = 0;
	    } else {	/* It is a file. */
		printf("%s/%s\n", path, fn);
	    }
	}
    }

    return res;
}


int
main(void)
{
	char pathbuf[64];
	int i;

	printf("\n");

	if (sdcard_init()) {
		printf("Nije detektirana MicroSD kartica.\n");
		return(1);
	}

	if (sdcard_cmd(SD_CMD_SEND_CID, 0) ||
	    sdcard_read((char *) pathbuf, 16)) {
		printf("SD_CMD_SEND_CID failed.\n");
		return(1);
	}

	printf("\nMicroSD kartica: ");
	for (i = 1; i < 8; i++)
		putchar(pathbuf[i]);

	printf(" rev %d", ((u_char) pathbuf[8] >> 4) * 10 + (pathbuf[8] & 0xf));

	printf(" S/N ");
	for (i = 9; i < 13; i++)
		printf("%02x", (u_char) pathbuf[i]);
	printf("\n");

	if (f_mount(0, &fh))
		printf("f_mount() failed\n");

	pathbuf[0] = 0;
	scan_files(pathbuf);

	if (f_mount(0, NULL))
		printf("f_mount() failed\n");

	printf("Done\n");

	return (0);
}
