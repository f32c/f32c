
#include <sys/param.h>
#include <io.h>
#include <spi.h>


#define	PCM_SKIP 	25000
#define	PCM_END		3000000
#define	PCM_TSC_CYCLES	1842	/* 81.25 MHz / 44.1 kHz */

#define	PCM_VOL_MAX	12
#define	PCM_VOL_MIN	0
#define	PCM_VOL_MUTE	0x80000000


int pcm_vol = PCM_VOL_MAX * 2 / 3;
int pcm_bal = 0;
int pcm_hi = 65530;
int pcm_lo = 0;
int pcm_reverb = 0;
int pcm_period = PCM_TSC_CYCLES;
int fm_freq = 0;		/* Pending TX frequency, in Hz */
int led_byte = -1;

static int pcm_addr = PCM_END;
static int pcm_lo_acc[2] = {0, 0};
static int pcm_hi_acc[2] = {0, 0};
static int pcm_rv1_acc[2] = {0, 0};
static int pcm_rv2_acc[2] = {0, 0};
static int pcm_rv3_acc[2] = {0, 0};
static int pcm_avg[2] = {0, 0};
static int pcm_vu[2] = {0, 0};
static int pcm_evol[2] = {0, 0};
static int pcm_next_tsc;
static int pcm_pushbtn_old;
static int dds_base;		/* 0 MHz - don't TX anything by default */
static int fm_mode;		/* Modulation depth */
static int fm_efreq;		/* Actual TX frequency, in Hz */

static int delay_idx = 0;


static void
update_dds_freq(void)
{

	fm_efreq = fm_freq;
	if (fm_freq >= 76000000 && fm_freq < 108000000) {
		fm_mode = 4;
	} else {
		if (fm_freq >= 174000000)
			fm_mode = 10;
		else
			fm_mode = 8;
	}

	dds_base = (fm_freq / 100) << 7;
	dds_base = (dds_base / 100) << 7;
	dds_base = (dds_base / 100) << 8;
	dds_base /= 325;
	if (fm_mode == 10)
		dds_base /= 3;
}


void
pcm_play(void)
{
	int pcm_out, dds_out, i, c, t, vu;
	short *sram = (short *) 0x88000000;
	
	RDTSC(c);
	c -= pcm_next_tsc;
	if (c < 0)
		c = -c;
	if (c < pcm_period)
		return;
	if (c > pcm_period << 4)
		RDTSC(pcm_next_tsc);
	else
		pcm_next_tsc += pcm_period;

	/* Read a sample from SPI flash */
	for (i = 0, pcm_out = 0, dds_out = 0; i < 2; i++) {
		/* Fetch a 16-bit PCM sample from SPI Flash */
		c = spi_byte_in(SPI_PORT_FLASH) |
		    (spi_byte_in(SPI_PORT_FLASH) << 8);

		/* Sign extend 16 -> 32 bit & update signal running average */
		if (c & 0x8000) {
			pcm_avg[i] =
			    ((pcm_avg[i] << 6) - pcm_avg[i] +
			    ((c ^ 0xffff) << 2)) >> 6;
			c += 0xffff0000;
		} else
			pcm_avg[i] =
			    ((pcm_avg[i] << 6) - pcm_avg[i] + (c << 2)) >> 6;

		/* Low pass filter */
		pcm_lo_acc[i] = c - (((c - pcm_lo_acc[i]) * pcm_lo) >> 16);
		c = pcm_lo_acc[i];

		/* High pass filter */
		pcm_hi_acc[i] = c - (((c - pcm_hi_acc[i]) * pcm_hi) >> 16);
		c = c - pcm_hi_acc[i];

		/* Reverb */
		t = c
		    + sram[delay_idx - 3110]
		    - sram[delay_idx - 7110]
		    + 2 * sram[delay_idx - 11110]
		    - sram[delay_idx - 15110]
		    - 2 * sram[delay_idx - 17122]
		    + sram[delay_idx - 23110];
		pcm_rv1_acc[i] = t - (((t - pcm_rv1_acc[i]) * 2800) >> 12);
		t = pcm_rv1_acc[i];
		pcm_rv2_acc[i] = t - (((t - pcm_rv2_acc[i]) * 3500) >> 12);
		t = t - pcm_rv2_acc[i];
		sram[delay_idx++] = (t * 7) >> 5;
		t = sram[delay_idx - 13101] * 9;
		pcm_rv3_acc[i] = t - (((t - pcm_rv3_acc[i]) * 3200) >> 12);
		t = pcm_rv3_acc[i];
		if (pcm_reverb) {
			c -= t;
			if (c > 32767)
				c = 32767;
			if (c < -32768)
				c = -32768;
		}
		
		/* 32 -> 16 bit */
		c &= 0xffff;

		/* Apply volume setting */
		pcm_out = (pcm_out << 16) |
		    ((c ^ 0x8000) * (pcm_evol[i] >> 5)) >> 11;

		/* Mix L & R channels for FM signal DDS */
		dds_out += c;
		if (c & 0x8000)
			dds_out += 0xffff0000;
	}
	OUTH(IO_PCM_OUT, pcm_out);
	OUTH(IO_PCM_OUT + 2, pcm_out >> 16);
	delay_idx &= 0x0fffff;
	delay_idx |= 0x100000;
	
	dds_out = dds_base + (dds_out >> fm_mode);
	OUTW(IO_DDS, dds_out);

	/* Update volume and VU meter */
	if ((pcm_addr & 0x3ff) == 0) {
		for (i = 0, vu = 0; i < 2; i++) {
			/* Volume */
			if (i)
				c = pcm_bal;
			else
				c = -pcm_bal;
			if (c > 0)
				c = 0;
			c += pcm_vol;
			if (c < PCM_VOL_MIN)
				c = PCM_VOL_MIN;
			c = 0x10 << c;
			pcm_evol[i] = c - (c - pcm_evol[i]) * 31 / 32;

			/* VU meter */
			pcm_vu[i] = (pcm_vu[i] - 0x0180) & 0xffff;
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
		if (led_byte >= 0) {
			OUTB(IO_LED, led_byte);
		} else {
			OUTB(IO_LED, vu);
		}

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
	} else {
		if (fm_freq != fm_efreq)
			update_dds_freq();
	}

	/* End of file, rewind SPI flash read position */
	pcm_addr += 4;
	if (pcm_addr >= PCM_END) {
		pcm_addr = PCM_SKIP;
		spi_start_transaction(SPI_PORT_FLASH);
		spi_byte(SPI_PORT_FLASH, 0x0b);	/* High-speed read */
		spi_byte(SPI_PORT_FLASH, pcm_addr >> 16);
		spi_byte(SPI_PORT_FLASH, pcm_addr >> 8);
		spi_byte(SPI_PORT_FLASH, pcm_addr);
		spi_byte_in(SPI_PORT_FLASH); /* dummy byte, ignored */
	}
}
