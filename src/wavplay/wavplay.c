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
	int i, f, block = 0, cur, got, cnt = 0, vol = 12;
	char *buf = (void *) 0x80080000;

	printf("Hello, FPGA world!\n");

	f = open("1:/route_66.wav", O_RDONLY);
	if (f < 0) {
		printf("Open failed\n");
		exit (1);
	}

	got = read(f, buf, 0x8000);
	OUTW(IO_PCM_FIRST, buf);
	OUTW(IO_PCM_LAST, buf + 0x7ffe);
	OUTW(IO_PCM_FREQ, 9108); /* 44.1 kHz sample rate */

	while (got > 0) {
		INW(cur, IO_PCM_CUR);
		if ((cur & 0x4000) != block) {
			got = read(f, buf + block, 0x4000);
			block = cur & 0x4000;
			cnt += got;
			INB(i, IO_PUSHBTN);
			if ((i & BTN_UP) && vol < 15)
				vol++;
			if ((i & BTN_DOWN) && vol > 0)
				vol--;
			OUTH(IO_PCM_VOLUME, vol + (vol << 8));
			printf("%d	%d\n", vol, cnt);
		}
	}

	OUTW(IO_PCM_FREQ, 0); /* O Hz sample rate - stop PCM DMA */
	OUTH(IO_PCM_VOLUME, 0); /* volume 0 on both channels - shut up PCM */
}
