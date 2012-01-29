
#include <types.h>
#include <endian.h>
#include <io.h>
#include <sdcard.h>
#include <sio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fatfs/ff.h>


/* From lib/pcmplay.c */

#define	PCM_TSC_CYCLES	71	/* 3.125 MHz / 44.1 kHz = 71 TSC cycles */

#define	PCM_VOL_MAX	12
#define	PCM_VOL_MIN	0
#define	PCM_VOL_MUTE	0x80000000

extern void pcm_play(void);

extern int fm_freq;
extern int pcm_vol;
extern int pcm_bal;
extern int pcm_hi;
extern int pcm_lo;
extern int pcm_reverb;
extern int pcm_period;
extern int led_byte;


static int old_pcm_vol, old_pcm_bal;
static int old_bauds = 115200;
static int new_bauds = 115200;


#define	BUFSIZE 256
char buf[BUFSIZE];

#define	MEMSIZE (BUFSIZE / 2)

static int idle_active = 0;
static int sd_scan_line;
static int sd_scan_stop;

FATFS fh;


FRESULT
scan_files(char* path)
{
	FRESULT res;
	FILINFO fno;
	DIR dir;
	int i, c;
	char *fn;
	char *cp;

	/* Open the directory */
	res = f_opendir(&dir, path);
	if (res != FR_OK)
		return (res);

	i = strlen(path);
	do {
		/* Read a directory item */
		res = f_readdir(&dir, &fno);
		if (res != FR_OK || fno.fname[0] == 0)
			break;

		/* Ignore dot entry */
		if (fno.fname[0] == '.')
			continue;

		fn = fno.fname;
		if (sd_scan_stop) {
			if (fno.fattrib & AM_DIR)
				c = 'd';
			else
				c = ' ';
			printf("%10d %c %s/%s\n", (int) fno.fsize, c,
			    path, fn);
		} else
			break;

		/* Pager */
		if (sd_scan_line++ == sd_scan_stop) {
			printf("--More-- (line %d)", sd_scan_line);
			c = getchar();
			printf("\r                      \r");
			if (c == 3 || c == 'q') {
				sd_scan_stop = 0;
				break;
			}
			sd_scan_stop = sd_scan_line;
			if (c == ' ')
				sd_scan_stop += 21;
		}

		/* Recursively scan subdirectories */
		if (fno.fattrib & AM_DIR) {
			cp = &path[i];
			*cp++ = '/';
			do {
				*cp++ = *fn;
			} while (*fn++ != 0);
			res = scan_files(path);
			if (res != FR_OK)
				break;
			path[i] = 0;
		}
	} while (1);

	return (res);
}


static void
sdcard_test(void)
{
	int i;

	if (sdcard_init() || sdcard_cmd(SD_CMD_SEND_CID, 0) ||
	    sdcard_read((char *) buf, 16)) {
		printf("Nije pronadjena MicroSD kartica.\n\n");
		return;
	}

	printf("MicroSD kartica: ");
	for (i = 1; i < 8; i++)
		putchar(buf[i]);

	printf(" rev %d", ((u_char) buf[8] >> 4) * 10 + (buf[8] & 0xf));

	printf(" S/N ");
	for (i = 9; i < 13; i++)
		printf("%02x", (u_char) buf[i]);
	printf("\n\n");

	f_mount(0, &fh);
	buf[0] = 0;
	sd_scan_line = 0;
	sd_scan_stop = 19;
	scan_files(buf);

	printf("\n");
}


void sram_wr(int a, int d)
{

	a <<= 2;

	__asm(
		".set noreorder\n"
		"lui	$3, 0x8000\n"
		"addu	$3, $3, %1\n"
#if _BYTE_ORDER == _BIG_ENDIAN
		"sll %0, 16\n"
#endif
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
#if _BYTE_ORDER == _BIG_ENDIAN
		"srl %0, 16\n"
#endif
		".set reorder\n"
		: "=r" (r)
		: "r" (a)
	);

	return (r);
}


static void
sram_test(void)
{
	int i, j, r, mem_offset;
	uint16_t *membuf = (uint16_t *) buf;
	
	printf("Ispitivanje SRAMa u tijeku...  ");
	for (j = 0; j < 4096; j++) {
		do {
			mem_offset = random() & 0x7ffff;
		} while (mem_offset > 512*1024 - MEMSIZE);
		r = random();
		for (i = 0; i < MEMSIZE; i++) {
			sram_wr(i + mem_offset, (i - (i << 9)) ^ r);
		}
		for (i = 0; i < MEMSIZE; i++) {
			membuf[i] = sram_rd(i + mem_offset);
		}
		for (i = 0; i < MEMSIZE; i++) {
			if (membuf[i] != (((i - (i << 9)) ^ r) & 0xffff)) {
				printf("Greska: neispravan SRAM!\n");
				return;
			}
		}
	}
	printf("SRAM OK!\n");
}


/*
 * Empirijske konstante i funkcije za konverziju granicnih frekvencija u
 * konstante audiofrekvencijskih IIR digitalnih filtara 1. reda, i obratno.
 */
#define	FC1	65700
#define	FC2	11000
#define	FC3	32768

static int
ctof(int c)
{
	int f;

	f = ((FC1 - c) * FC2) / (FC3 + c);
	if (f > 20000)
		f = 20000;
	if (f < 20)
		f = 20;
	return(f);
}


static int
ftoc(int f)
{
	int c;

	c = (FC1 * FC2 - FC3 * f) / (FC2 + f);
	return(c);
}


static void
redraw_display()
{
	int val;

	printf("\n");
	printf("FER - Digitalna logika 2011/2012\n");
	printf("\n");
	printf("ULX2S FPGA plocica - demonstracijsko-dijagnosticki program\n");
	printf("v 0.96 29/01/2012\n");
	printf("\n");
	printf("Glavni izbornik:\n");
	printf("\n");
	printf(" 1: Glasnoca: %d (zvucni izlaz ", pcm_vol & ~PCM_VOL_MUTE);
	if (pcm_vol & PCM_VOL_MUTE)
		printf("iskljucen)\n");
	else
		printf("ukljucen)\n");
	printf(" 2: Balans (L/D): %d\n", pcm_bal);
	printf(" 3: Jeka ");
	if (pcm_reverb)
		printf("ukljucena\n");
	else
		printf("iskljucena\n");
	printf(" 4: Tonfrekvencijski pojas (-3 dB): %d-%d Hz\n",
	    ctof(pcm_hi), ctof(pcm_lo));
	printf(" 5: Brzina reprodukcije: %d%%\n",
	    PCM_TSC_CYCLES * 100 / pcm_period);
	printf(" 6: Frekvencija odasiljanja FM signala: %d.%04d MHz\n",
	    fm_freq / 1000000, (fm_freq % 1000000) / 100);
	printf(" 7: LED indikatori: ");
	if (led_byte < 0)
		printf("VU-metar\n");
	else
		printf("0x%02x (%d)\n", led_byte, led_byte);
	printf(" 8: USB UART (RS-232) baud rate: %d bps\n", new_bauds);
	printf(" 9: Ispitaj SRAM\n");
	printf(" 0: Ispisi sadrzaj kazala MicroSD kartice\n");
	printf("\n");

	/* Recompute and set baudrate */
	if (old_bauds != new_bauds) {
		old_bauds = new_bauds;
		val = new_bauds * 1024 / 1000 * 1024 / 81250 + 1;
		OUTW(IO_SIO_BAUD, val);
	}
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
	int i, hi, lo, res;
	char c;

	/* Register PCM output function as idle loop handler */
	sio_idle_fn = demo_idle;

	do {
		c = getchar();
		switch (c) {
		case 3: /* CTRL + C */
			res = -1;
			break;
		case '+':
			if ((pcm_vol & ~PCM_VOL_MUTE) < PCM_VOL_MAX)
				pcm_vol++;
			break;
		case '-':
			if ((pcm_vol & ~PCM_VOL_MUTE) > PCM_VOL_MIN)
				pcm_vol--;
			break;
		case ' ':
			pcm_vol ^= PCM_VOL_MUTE;
			break;
		case '1':
			printf("Unesite glasnocu (0 do 12): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (buf[0] != 0 && i >= PCM_VOL_MIN &&
			    i <= PCM_VOL_MAX) {
				pcm_vol = i;
				old_pcm_vol = i;
			}
			break;
		case '2':
			printf("Unesite balans (-6 do 6): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (i >= -6 && i <= 6) {
				pcm_bal = i;
				old_pcm_bal = i;
			}
			break;
		case '3':
			pcm_reverb ^= 1;
			break;
		case '4':
			printf("Unesite frekvencijski raspon u Hz"
			    " (20 do 20000): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			lo = atoi(buf);
			for (i = 0; buf[i] != ' ' && buf[i] != '-' &&
			    buf[i] != 'k' && buf[i] != 0; i++) {};
			if (i == 0)
				break;
			if (buf[i] == 'k') {
				lo *= 1000;
				i++;
			}
			if (buf[i++] == 0) {
				if (lo == 0) {
					pcm_lo = 0;
					pcm_hi = 65530;
				} else if (lo >= 20 && lo <= 20000)
					pcm_hi = pcm_lo = ftoc(lo);
				break;
			}
			hi = atoi(&buf[i]);
			for (; buf[i] != 'k' && buf[i] != 0; i++) {};
			if (buf[i] == 'k')
				hi *= 1000;
			if (lo >= 20 && hi <= 20000 && lo <= hi) {
				pcm_hi = ftoc(lo);
				pcm_lo = ftoc(hi);
			}
			break;
		case '5':
			printf("Unesite brzinu reprodukcije"
			    " (50%% do 200%%): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (i >= 50 && i <= 200)
				pcm_period = PCM_TSC_CYCLES * 100 / i;
			break;
		case '6':
			res = update_fm_freq();
			break;
		case '7':
			printf("Unesite vrijednost za LED byte (0 do 255): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (buf[0] != 0 && i >= 0 && i <= 255)
				led_byte = i;
			else
				led_byte = -1;
			break;
		case '8':
			printf("Unesite zeljeni baud rate"
			    " (300 do 460800 bps): ");
			if (gets(buf, BUFSIZE) != 0)
				return (0);	/* Got CTRL + C */
			i = atoi(buf);
			if (buf[0] != 0 && i >= 300 && i <= 460800)
				new_bauds = i;
			break;
		case '9':
			sram_test();
			continue;
		case '0':
			sdcard_test();
			continue;
		}
		redraw_display();
	} while (res == 0);

	printf("Pritisnite 'x' za povratak u glavni izbornik.\n");
	return (0);
}


