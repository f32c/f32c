
#include <io.h>
#include <sio.h>
#include <stdio.h>
#include <types.h>


/* From lib/pcmplay.c */

#define	PCM_TSC_CYCLES	71	/* 3.125 MHz / 44.1 kHz = 71 TSC cycles */

#define	PCM_VOL_MAX	12
#define	PCM_VOL_MIN	0
#define	PCM_VOL_MUTE	0x80000000

extern void pcm_play(void);

extern int fm_freq;
extern int pcm_vol;
extern int pcm_bal;
extern int pcm_period;


static int old_fm_freq, old_pcm_vol, old_pcm_bal, old_pcm_period;


#define BUFSIZE 80

char buf[BUFSIZE];
static int idle_active = 0;


static int
atoi(const char *b)
{
	int i = 0;
	const char *c;

	for (c = b; *c != '\0'; c++) {
		if (*c >= '0' && *c <= '9') {
			i = i * 10 + (*c - '0');
		} else
			break;
	}

	return (i);
}


static void
redraw_display()
{

	printf("\n");
	printf("FER - Digitalna logika 2011/2012\n");
	printf("\n");
	printf("ULX2S plocica - demonstracijski / dijagnosticki FPGA bitstream"
	    " v 0.01\n");
	printf("\n");
	printf("Glavni izbornik:\n");
	printf("\n");
	printf("1: Zvuk ukljucen: %d\n", (pcm_vol & PCM_VOL_MUTE) == 0);
	printf("2: Glasnoca: %d\n", pcm_vol & ~PCM_VOL_MUTE);
	printf("3: Balans (L/D): %d\n", pcm_bal);
	printf("4: Brzina reprodukcije: %d%%\n",
	    PCM_TSC_CYCLES * 100 / pcm_period);
	printf("5: Frekvencija odasiljanja FM signala: %d.%04d MHz\n",
	    fm_freq / 1000000, (fm_freq % 1000000) / 100);
	printf("\n");
	printf("CTRL+C: izlaz u MIPS bootloader\n");
	printf("\n");
}


void
demo_idle()
{

	pcm_play();
	if (idle_active)
		return;
	idle_active++;

	if (old_fm_freq != fm_freq || old_pcm_vol != pcm_vol ||
	    old_pcm_bal != pcm_bal || old_pcm_period != pcm_period) {
		old_fm_freq = fm_freq;
		old_pcm_vol = pcm_vol;
		old_pcm_bal = pcm_bal;
		old_pcm_period = pcm_period;
		redraw_display();
	}
	idle_active--;
}


static int
update_fm_freq()
{
	char *c;
	int f_c, f_d, freq_i, freq_f;

	printf("\nUnesite zeljenu frekvenciju u MHz: ");
	if (gets(buf, BUFSIZE) != 0)
		return (-1);	/* Got CTRL + C */
	if (*buf == '0') {
		fm_freq = 0;
		return (0);
	}
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
		printf("\nGreska: moguce je sintetizirati samo FM signal"
		    " frekvencije do 512 MHz.\n\n");
		return (0);
	}
	if (freq_i) {
		while (f_c > 0) {
			f_c--;
		}
		while (f_d != 10000) {
			f_d *= 10;
			freq_f *= 10;
		}
		fm_freq = freq_i * 1000000 + freq_f * 100;
	}
	return (0);
}


int
main(void)
{
	int i, res;
	char c;

	/* Register PCM output function as idle loop handler */
	sio_idle_fn = demo_idle;

	do {
		redraw_display();
		c = getchar();
		switch (c) {
		case 3: /* CTRL + C */
			res = -1;
			break;
		case '1':
			pcm_vol ^= PCM_VOL_MUTE;
			break;
		case '2':
			printf("\nUnesite glasnocu (0 do 12): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (i >= 0 && i <= 12)
				pcm_vol = i;
			break;
		case '3':
			printf("\nUnesite balans (-6 do 6): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (i >= -6 && i <= 6)
				pcm_bal = i;
			break;
		case '4':
			printf("\nUnesite brzinu reprodukcije"
			    " (50%% do 200%%): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (i >= 50 && i <= 200)
				pcm_period = PCM_TSC_CYCLES * 100 / i;
			break;
		case '5':
			res = update_fm_freq();
			break;
		}
	} while (res == 0);

	printf("Pritisnite 'x' za povratak u glavni izbornik.\n");
	return (0);
}


