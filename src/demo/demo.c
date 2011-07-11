
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
	int freq_i, freq_f, f_c, f_d;

	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

	do {
		printf("Enter DDS frequency: ");
		for (freq_i = 0, freq_f = 0, f_c = -1, f_d = 1;
		    (c = getchar()) != '\r';) {
			/* Exit to bootloader on CTRL+C */
			if (c == 3)
				return(0);
			putchar(c);
			if (c >= '0' && c <= '9') {
				if (f_c >= 0) {
					if (f_d == 10000)
						continue;
					freq_f = freq_f * 10 + c - '0';
					f_d *= 10;
					if (freq_f == 0 && c == '0')
						f_c++;
				} else
					freq_i = freq_i * 10 + c - '0';
			}
			if (c == '.')
				f_c = 0;
		}
		printf("\n\n");
		if (freq_i >= 512) {
			printf("Can't synthesize frequencies above"
			    " 512 MHz\n\n");
			continue;
		}
		printf("Using %d.", freq_i);
		while (f_c > 0) {
			f_c--;
			printf("0");
		}
		printf("%d MHz as DDS frequency, ", freq_f);
		if (freq_i >= 76 && freq_i < 108) {
			printf("wide modulation.");
			fm_mode = 4;
		} else {
			printf("narrow modulation.");
			if (freq_i >= 174)
				fm_mode = 10;
			else
				fm_mode = 8;
		}
		printf("\n\n");
		dds_base = freq_i << 22;
		if (f_d > 1)
			dds_base += ((1 << 16) * freq_f / f_d) << 6;
		dds_base /= 325;
		if (fm_mode == 10)
			dds_base /= 3;
	} while (1);
}
