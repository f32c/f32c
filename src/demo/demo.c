
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>


extern void pcm_play(void);

extern int fm_freq;


#define BUFSIZE 80

char buf[BUFSIZE];
static int idle_active = 0;
static int idle_tsc;
static int idle_cnt = 0;
static char idle_msg[] =
    "FER ULXP2 board                                                 ";


void
demo_idle()
{
	int c;

	pcm_play();
	if (idle_active)
		return;
	c = rdtsc() - idle_tsc;
	if (c < 0)
		c = -c;

	/* Execute every second */
	if (c < 3125000 / 4)
		return;

	idle_tsc += c;
	idle_active++;
	idle_cnt++;

	/* Store cursor, print something, restore cursor */
	printf("7[1A\r");
	for (c = 0; c < 64; c++)
		putchar(idle_msg[(c + idle_cnt) & 0x3f]);
	printf("8");

	idle_active--;
}


int
main(void)
{
	char *c;
	int f_c, f_d, freq_i, freq_f;

	/* Register PCM output function as idle loop handler */
	sio_idle_fn = demo_idle;

	do {
		printf("\nEnter DDS frequency: ");
		if (gets(buf, BUFSIZE) != 0)
			return (0);	/* Got CTRL + C */
		for (c = buf, freq_i = 0, freq_f = 0, f_c = -1, f_d = 1;
		    *c != '\0'; c++) {
			if (*c >= '0' && *c <= '9') {
				if (f_c >= 0) {
					if (f_d == 10000)
						continue;
					freq_f = freq_f * 10 + *c - '0';
					f_d *= 10;
					if (freq_f == 0 && *c == '0')
						f_c++;
				} else
					freq_i = freq_i * 10 + *c - '0';
			}
			if (*c == '.')
				f_c = 0;
		}
		if (freq_i >= 512) {
			printf("Can't synthesize frequencies above"
			    " 512 MHz\n\n");
			continue;
		}
		if (freq_i) {
			printf("Using %d.", freq_i);
			while (f_c > 0) {
				f_c--;
				printf("0");
			}
			printf("%d MHz as DDS frequency\n", freq_f);
			while (f_d != 10000) {
				f_d *= 10;
				freq_f *= 10;
			}
			fm_freq = freq_i * 1000000 + freq_f * 100;
		}
	} while (1);
}
