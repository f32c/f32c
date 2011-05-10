
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>


extern void pcm_play(void);

extern int dds_base;
extern int fm_mode;


int
main(void)
{
	u_char c;
	int freq;

	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

	do {
		printf("Enter DDS frequency: ");
		for (freq = 0; (c = getchar()) != '\r';) {
			/* Exit to bootloader on CTRL+C */
			if (c == 3)
				return(0);
			putchar(c);
			if (c >= '0' && c <= '9') {
				freq = freq * 10 + c - '0';
			} else
				break;
		}
		printf("\n\n");
		printf("Using %d MHz as DDS frequency, ", freq);
		if (freq >= 76 && freq <= 108) {
			printf("wide modulation.");
			fm_mode = 4;
		} else {
			printf("narrow modulation.");
			if (freq > 255)
				fm_mode = 10;
			else
				fm_mode = 8;
		}
		printf("\n\n");
		dds_base = (freq << 22) / 300;
		if (fm_mode == 10)
			dds_base /= 3;
	} while (1);
}
