
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>


#define	PCM_SKIP 	25000
#define	PCM_END		3000000
#define	PCM_TSC_CYCLES	71	/* 3.125 MHz / 44.1 kHz = 71 TSC cycles */

#define	PCM_VOL_MAX	12
#define	PCM_VOL_MIN	0
#define	PCM_VOL_MUTE	0x80000000


static int pcm_addr = PCM_END;
static int pcm_vol = PCM_VOL_MAX * 2 / 3;
static int pcm_bal = 0;
static int pcm_avg[2] = {0, 0};
static int pcm_vu[2] = {0, 0};
static int pcm_evol[2] = {0, 0};
static int pcm_next_tsc;
static int pcm_period = PCM_TSC_CYCLES;
static int pcm_pushbtn_old;

int dds_base;			/* 0 MHz - don't TX anything by default */
int fm_mode;			/* modulation depth */


void
pcm_play(void)
{
	int pcm_out, dds_out, i, c, vu;
	
	c = rdtsc() - pcm_next_tsc;
	if (c < 0)
		c = -c;
	if (c < pcm_period)
		return;
	if (c > pcm_period << 4)
		pcm_next_tsc = rdtsc();
	else
		pcm_next_tsc += pcm_period;

	/* Read a sample from SPI flash */
	for (i = 0, pcm_out = 0, dds_out = 0; i < 2; i++) {
		/* Fetch a 16-bit PCM sample from SPI Flash */
		c = spi_byte_in() | (spi_byte_in() << 8);

		/* Apply volume setting */
		pcm_out = (pcm_out << 16) |
		    ((c ^ 0x8000) * (pcm_evol[i] >> 5)) >> 11;

		/* Mix L & R channels for DDS synthesis */
		dds_out += c;
		if (c & 0x8000)
			dds_out += 0xffff0000;

		/* Update signal running average */
		if (c & 0x8000)
			c ^= 0xffff;
		pcm_avg[i] = ((pcm_avg[i] << 6) - pcm_avg[i] + (c << 2)) >> 6;
	}
	OUTW(IO_PCM_OUT, pcm_out);
	
	dds_out = dds_base + (dds_out >> fm_mode);
	OUTW(IO_DDS, dds_out);

	/* Update volume and VU meter */
	if ((pcm_addr & 0xfff) == 0) {
		for (i = 0, vu = 0; i < 2; i++) {
			/* Volume */
			if (i)
				c = pcm_bal;
			else
				c = -pcm_bal;
			if (c > 0)
				c = 0;
			c += pcm_vol;
			if (c < PCM_VOL_MIN) {
				pcm_evol[i] =
				    ((pcm_evol[i] << 3) - pcm_evol[i]) >> 3;
			} else
				pcm_evol[i] =
				    (((pcm_evol[i] << 4) - pcm_evol[i]) +
				    (0x10 << c) + 0xf) >> 4;

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
			if ((pcm_vol & PCM_VOL_MUTE) == 0) {
				pcm_vol +=
				    ((vu & BTN_UP) && pcm_vol < PCM_VOL_MAX);
				pcm_vol -=
				    ((vu & BTN_DOWN) && pcm_vol > PCM_VOL_MIN);
				pcm_bal -=
				    ((vu & BTN_LEFT) &&
				    pcm_bal > -PCM_VOL_MAX >> 1);
				pcm_bal +=
				    ((vu & BTN_RIGHT) &&
				    pcm_bal < PCM_VOL_MAX >> 1);
			}
			if (vu & BTN_CENTER)
				pcm_vol ^= PCM_VOL_MUTE;
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
		spi_byte_in(); /* dummy byte, ignored */
	}
}
