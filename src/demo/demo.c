
#include <io.h>
#include <types.h>
#include <sio.h>
#include <stdio.h>
#include <stdlib.h>


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
extern int led_mode;
extern int led_byte;


static int old_pcm_vol, old_pcm_bal;
static int bauds = 115200;


#define BUFSIZE 64
#define	MEMSIZE 4000
#define MEM_OFFSET 333333

char buf[BUFSIZE];
uint16_t ibuf[MEMSIZE];

static int idle_active = 0;


void sram_wr(int a, int d)
{

	a <<= 2;

	__asm(
		".set noreorder\n"
		"lui	$3, 0x8000\n"
		"addu	$3, $3, %1\n"
		"sw %0, 0($3)\n"
		"sw %0, 0($3)\n"
		"sw %0, 0($3)\n"
		"sw %0, 0($3)\n"
		".set reorder\n"
		:
		: "r" (d), "r" (a)
	);
}


int sram_rd(int a)
{
	int r;

	a <<= 2;

	__asm(
		".set noreorder\n"
		"lui	$3, 0x8000\n"
		"addu	$3, $3, %1\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		"lw %0, 0($3)\n"
		".set reorder\n"
		: "=r" (r)
		: "r" (a)
	);

	return (r);
}


static void
sram_test(void)
{
	int i, j, mem_offset;
	
	printf("SRAM self-test u tijeku...  ");
	for (j = 0; j < 100; j++) {
		do {
			mem_offset = random() & 0x7ffff;
		} while (mem_offset > 512*1024 - MEMSIZE);
		for (i = 0; i < MEMSIZE; i++) {
			sram_wr(i + mem_offset, random());
		}
		for (i = 0; i < MEMSIZE; i++) {
			sram_wr(i + mem_offset, i);
		}
		for (i = 0; i < MEMSIZE; i++) {
			ibuf[i] = sram_rd(i + mem_offset);
		}
		for (i = 0; i < MEMSIZE; i++) {
			if (ibuf[i] != i) {
				printf("Greska: neispravan SRAM!\n");
				return;
			}
		}
	}
	printf("SRAM OK!\n");

#if 0
	do {
		printf("Enter RD addr: ");
		if (gets(buf, BUFSIZE) != 0)
			return (0);	/* Got CTRL + C */
		i = atoi(buf);
		printf("sram(%06d): %08x\n", i, sram_rd(i));

		printf("Enter WR addr: ");
		if (gets(buf, BUFSIZE) != 0)
			return (0);	/* Got CTRL + C */
		i = atoi(buf);
		printf("Enter WR data: ");
		if (gets(buf, BUFSIZE) != 0)
			return (0);	/* Got CTRL + C */
		j = atoi(buf);
		sram_wr(i, j);
	} while (0);
#endif
}

static void
redraw_display()
{

	printf("\n");
	printf("FER - Digitalna logika 2011/2012\n");
	printf("\n");
	printf("ULX2S FPGA plocica - demonstracijsko-dijagnosticki program\n");
	printf("v 0.02 27/09/2011\n");
	printf("\n");
	printf("Glavni izbornik:\n");
	printf("\n");
	printf(" 1: Audio izlaz ukljucen: %d\n",
	    (pcm_vol & PCM_VOL_MUTE) == 0);
	printf(" 2: Glasnoca: %d\n", pcm_vol & ~PCM_VOL_MUTE);
	printf(" 3: Balans (L/D): %d\n", pcm_bal);
	printf(" 4: Brzina reprodukcije: %d%%\n",
	    PCM_TSC_CYCLES * 100 / pcm_period);
	printf(" 5: Frekvencija odasiljanja FM signala: %d.%04d MHz\n",
	    fm_freq / 1000000, (fm_freq % 1000000) / 100);
	printf(" 6: LED indikatori (0: VU-metar, 1: byte): %d\n", led_mode);
	printf(" 7: LED byte: %d\n", led_byte);
	printf(" 8: USB UART (RS-232) baud rate: %d bps\n", bauds);
	printf(" 9: SRAM self-test\n");
	printf("\n");
	OUTW(IO_SIO_BAUD, 81250000 / bauds);
}


void
demo_idle()
{

	pcm_play();
	if (idle_active)
		return;
	idle_active++;

	if (old_pcm_vol != pcm_vol || old_pcm_bal != pcm_bal) {
		old_pcm_vol = pcm_vol;
		old_pcm_bal = pcm_bal;
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
printf("XXX FM_FREQ: %d\n", fm_freq);
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
			printf("Unesite glasnocu (0 do 12): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (buf[0] != 0 && i >= 0 && i <= 12) {
				pcm_vol = i;
				old_pcm_vol = i;
			}
			break;
		case '3':
			printf("Unesite balans (-6 do 6): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (i >= -6 && i <= 6) {
				pcm_bal = i;
				old_pcm_bal = i;
			}
			break;
		case '4':
			printf("Unesite brzinu reprodukcije"
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
		case '6':
			led_mode ^= 1;
			break;
		case '7':
			printf("Unesite vrijednost za LED byte (0 do 255): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (buf[0] != 0 && i >= 0 && i <= 255)
				led_byte = i;
			break;
		case '8':
			printf("Unesite zeljeni baud rate"
			    " (2400 do 230400 bps): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (buf[0] != 0 && i >= 2400 && i <= 230400)
				bauds = (i / 2400) * 2400;
			break;
		case '9':
			sram_test();
			break;
		}
	} while (res == 0);

	printf("Pritisnite 'x' za povratak u glavni izbornik.\n");
	return (0);
}


