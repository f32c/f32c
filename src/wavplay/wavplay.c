/*
 * Play WAV files stored on a MicroSD card.
 *
 * $Id$
 */

#include <sys/param.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <io.h>

void
main(void)
{
	int f, block, cur, got, cnt;
	char *buf = (void *) 0x80080000;

	printf("Hello, FPGA world!\n");

	f = open("1:/route_66.wav", O_RDONLY);
	if (f < 0) {
		printf("Open failed\n");
		exit (1);
	}

	got = read(f, buf, 0x8000);
	block = 0;
	cnt = 0;

	OUTW(IO_PCM_FIRST, buf);
	OUTW(IO_PCM_LAST, buf + 0x7ffe);
	OUTW(IO_PCM_FREQ, 9108); /* 44.1 kHz sample rate */

	while (got > 0) {
		INW(cur, IO_PCM_CUR);
		if ((cur & 0x4000) != block) {
			got = read(f, buf + block, 0x4000);
			block = cur & 0x4000;
			cnt += got;
			printf("%d\n", cnt);
		}
	}

	OUTW(IO_PCM_FREQ, 0); /* O Hz sample rate = shut down PCM output */
}
