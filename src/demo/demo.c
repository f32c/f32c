
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>


#define	PCM_SKIP 	25000
#define	PCM_END		3000000
#define	PCM_TSC_CYCLES	71	/* 3.125 MHz / 44.1 kHz = 71 TSC cycles */

#define	PCM_VOL_MAX	12
#define	PCM_VOL_MIN	1


static int pcm_addr = PCM_END;
static int pcm_vol = 8;
static int pcm_bal;
static int pcm_mute;
static int pcm_avg[2];
static int pcm_vu[2];
static int pcm_evol[2];
static int pcm_tsc;
static int pcm_pushbtn_old;

static int pcm_tsc_len;
static int pcm_cnt;


static void
pcm_play(void)
{
	int pcm_out[2];
	int i;
	int c;
	int vu;
	
	c = rdtsc() - pcm_tsc;
	if (c < 0)
		c = -c;
	if (c < PCM_TSC_CYCLES) {
pcm_tsc_len += c;
		return;
	}
	if (c > PCM_TSC_CYCLES << 4) {
pcm_cnt ++;
		pcm_tsc = rdtsc();
	}

	/* Read a sample from SPI flash */
	for (i = 0; i < 2; i++) {
		c = spi_byte_in() | (spi_byte_in() << 8);
		pcm_out[i] = c ^ 0x8000;
		if (c & 0x8000)
			c ^= 0xffff;
		/* Update signal running average before changing the volume */
		pcm_avg[i] = ((pcm_avg[i] << 6) - pcm_avg[i] + (c << 2)) >> 6;
	}

	/* Apply volume setting */
	for (i = 0; i < 2; i++) {
//		pcm_out[i] = (pcm_out[i] << pcm_vol) >> 12;
		pcm_out[i] = (pcm_out[i] * (pcm_evol[i] >> 4)) >> 12;
	}
	OUTH(IO_PCM_OUT + 2, pcm_out[0]);
	OUTH(IO_PCM_OUT, pcm_out[1]);
	
	/* Update volume and VU meter */
	if ((pcm_addr & 0xfff) == 0) {
		vu = 0;
		for (i = 0; i < 2; i++) {
			/* Volume */
			if (i)
				c = pcm_bal;
			else
				c = -pcm_bal;
			if (c > 0)
				c = 0;
			c += pcm_vol;
			if (pcm_mute)
				c = 0;
			pcm_evol[i] =
			    (((pcm_evol[i] << 4) - (pcm_evol[i] << pcm_mute))
			    + (0x10 << c) + 0xf) >> 4;

			/* VU meter */
			pcm_vu[i] = pcm_vu[i] - 0x0400;
			if (pcm_avg[i] >= pcm_vu[i])
				pcm_vu[i] = pcm_avg[i];
			if (pcm_vu[i] > 0x6800)
				c = 0xf;
			else if (pcm_vu[i] > 0x5400)
				c = 0x7;
			else if (pcm_vu[i] > 0x3800)
				c = 0x3;
			else if (pcm_vu[i] > 0x1e00)
				c = 0x1;
			else
				c = 0;
			vu |= (c << (i << 2));
		}
		OUTB(IO_LED, vu);

		INB(vu, IO_PUSHBTN);
		if (vu != pcm_pushbtn_old) {
			if ((vu & BTN_UP) && pcm_vol < PCM_VOL_MAX)
				pcm_vol++;
			if ((vu & BTN_DOWN) && pcm_vol > PCM_VOL_MIN)
				pcm_vol--;
			if ((vu & BTN_LEFT) && pcm_bal > -PCM_VOL_MAX >> 1)
				pcm_bal--;
			if ((vu & BTN_RIGHT) && pcm_bal < PCM_VOL_MAX >> 1)
				pcm_bal++;
			if (vu & BTN_CENTER)
				pcm_mute ^= 1;
		}
		pcm_pushbtn_old = vu;
	}

	/* End of file, rewind SPI flash read position */
	pcm_addr += 4;
	if (pcm_addr >= PCM_END) {
		pcm_addr = PCM_SKIP;
		spi_stop_transaction();
		spi_start_transaction();
		spi_byte(0x0b);	/* High-speed read */
		spi_byte(pcm_addr >> 16);
		spi_byte(pcm_addr >> 8);
		spi_byte(pcm_addr);
		spi_byte_in();
	}

#if 0
	c = rdtsc() - pcm_tsc;
	if (c < 0)
		c = -c;
	pcm_tsc_len += c;
	pcm_cnt ++;
#endif

	pcm_tsc += PCM_TSC_CYCLES;
}


int
main(void)
{
	char c;

	/* Register our PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

	printf("\n");

	do {
		c = getchar();

printf("pcm_tsc_len: %d pcm_cnt: %d avg: %d\n", pcm_tsc_len, pcm_cnt, pcm_tsc_len / pcm_cnt);
pcm_tsc_len = 0;
pcm_cnt = 0;
	} while (1);
}
