
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>


#define	PCM_SKIP 	25000
#define	PCM_END		3000000
#define	PCM_TSC_CYCLES	71	/* 3.125 MHz / 44.1 kHz = 71 TSC cycles */


static int pcm_addr = PCM_SKIP;
static int pcm_vol = 8;
static int pcm_avg[2];
static int pcm_evol[2];
static int pcm_tsc;

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
	if (c > PCM_TSC_CYCLES * 4) {
pcm_cnt ++;
		pcm_tsc = rdtsc();
	}

	/* Read a sample from SPI flash and send it to the DAC */
	spi_start_transaction();
	spi_byte(0x0b);	/* High-speed read */
	spi_byte(pcm_addr >> 16);
	spi_byte(pcm_addr >> 8);
	spi_byte(pcm_addr);
	spi_byte(0x0);
	for (i = 0; i < 2; i++)
		pcm_out[i] = (((spi_byte(0) & 0xff) |
		    ((spi_byte(0) & 0xff) << 8)) ^ 0x8000) & 0xffff;
	spi_stop_transaction();
	pcm_addr += 4;
	if (pcm_addr >= PCM_END)
		pcm_addr = PCM_SKIP;

	/* Update signal average before changing the volume */
	for (i = 0; i < 2; i++) {
		c = pcm_out[i] & 0xffff;
		c -= 0x8000;
		if (c < 0)
			c = -c;
		pcm_avg[i] = ((pcm_avg[i] << 6) - pcm_avg[i] + (c << 2)) >> 6;
	}

	/* Apply volume setting */
	for (i = 0; i < 2; i++) {
//		pcm_out[i] = (pcm_out[i] << pcm_vol) >> 12;
		pcm_out[i] = (pcm_out[i] * (pcm_evol[i] >> 4)) >> 12;
		if (pcm_out[i] > 0xffff)
			pcm_out[i] = 0xffff;
		if (pcm_out[i] < 0)
			pcm_out[i] = 0;
	}
	OUTW(IO_PCM_OUT, (pcm_out[0] << 16) | (pcm_out[1] & 0xffff));
	
	/* VU - meter */
	if ((pcm_addr & 0xfff) == 0) {
	vu = 0;
	for (i = 0; i < 2; i++) {
		if (pcm_avg[i] > 0x6000)
			c = 0xf;
		else if (pcm_avg[i] > 0x4000)
			c = 0x7;
		else if (pcm_avg[i] > 0x2000)
			c = 0x3;
		else if (pcm_avg[i] > 0x1000)
			c = 0x1;
		else
			c = 0;
		vu |= (c << (i * 4));
	}
	OUTB(IO_LED, vu);
		for (i = 0; i < 2; i++) {
			pcm_evol[i] = (((pcm_evol[i] << 4) - pcm_evol[i]) +
			    (0x10 << pcm_vol) + 0xf) >> 4;
		}
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

	/* Just in case we got started without a bootloader... */
	__asm __volatile__(
		"li $29, (0x80000000);"
		"li $27, %0"
		:
		: "i" (IO_BASE)
	);

	/* Register our PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

	printf("\n");

	do {
		c = getchar();

printf("pcm_tsc_len: %d pcm_cnt: %d avg: %d\n", pcm_tsc_len, pcm_cnt, pcm_tsc_len / pcm_cnt);
pcm_tsc_len = 0;
pcm_cnt = 0;
		if (c == '+' && pcm_vol < 15)
			pcm_vol++;
		if (c == '-' && pcm_vol > 0)
			pcm_vol--;

		printf("%d\n", pcm_vol);
	} while (1);
}
