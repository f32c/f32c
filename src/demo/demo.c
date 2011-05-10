
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
		if (freq == 0)
			continue;
		if (freq > 255) {
			printf("Frequency must be below 255 MHz.\n");
			continue;
		}
		if (freq > 108 && freq < 137) {
			printf("Oops, don't TX in AIR band!\n");
			continue;
		}
		printf("Using %d MHz as DDS frequency, ", freq);
		if (freq >= 76 && freq <= 108) {
			printf("wide modulation.");
			fm_mode = 0;
		} else {
			printf("narrow modulation.");
			fm_mode = 1;
		}
		printf("\n\n");
		dds_base = (freq << 24) / 300;
	} while (1);
}
