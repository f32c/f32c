
#include <sys/param.h>
#include <io.h>
#include <stdlib.h>
#include <stdio.h>


static int dds_base;
static int fwd_rev, left_right, turr_left, turr_right, gun_elev, gun_bullet;
static int mg_sound, gun_sound, engine_key;


static void
wait(int len)
{
	static int t0;
	int t1, d;

	do {
		RDTSC(t1);
		d = t1 - t0;
		if (d < 0)
			d = -d;
	} while (d < len);
	t0 = t1;
}


static void
txbit(int bit, int len)
{
	int dds_out;

	if (bit) {
		dds_out = dds_base - 20;
		OUTW(IO_DDS, dds_out);
		wait(len);
	} else {
		dds_out = dds_base + 20;
		OUTW(IO_DDS, dds_out);
		wait(len);
	}
}


/*
 * 32 bits = 20 ms -> 0.625 ms / bit -> 1600 bit / s
 * 1 bit = 2 symbols
 * 64 symbols = 20 ms -> 0.3125 ms / symbol
 */

#define CYCLE 25390 /* za ftsc = 81.25 MHz */


static void
fm_tx(void)
{
	int i, t;
	int outw, csum;

	csum = 4;
	csum ^= mg_sound;
	csum ^= 2 * gun_sound;
	csum ^= 2 * engine_key;
	csum ^= 2 * gun_bullet;
	csum ^= 4 * gun_elev;
	csum ^= 8 * turr_left;
	csum ^= turr_right;
	csum ^= fwd_rev << 2;
	csum ^= ((fwd_rev & 0xfc) >> 2);
	csum ^= left_right;
	csum ^= (left_right >> 4);
	csum &= 0xf;

	outw = 0x7;
	outw |= 0x3 << 24;
	outw |= fwd_rev << 19;
	outw |= left_right << 9;
	outw |= turr_left << (31 - 15);
	outw |= turr_right << (31 - 14);
	outw |= gun_elev << (31 - 16);
	outw |= gun_bullet << (31 - 17);
	outw |= gun_sound << (31 - 13);
	outw |= mg_sound << (31 - 24);
	outw |= engine_key << (31 - 23);
	outw |= csum << 3;

	txbit(0, 2 * CYCLE);
	txbit(0, CYCLE);
	txbit(1, CYCLE);

	t = outw;
	for (i = 0; i < 31; i++) {
		if (t & 0x80000000) {
			txbit(1, CYCLE);
			txbit(0, CYCLE);
		} else {
			txbit(0, CYCLE);
			txbit(1, CYCLE);
		}
		t <<= 1;
	}

	txbit(1, 14 * CYCLE + CYCLE / 4);
}


#if 0
int
main(void)
{
	int i;

	dds_base = 350321; /* 325 MHz PLL, 27.145 MHz */

	turr_left = 1;
	turr_right = 1;
	gun_elev = 1;
	gun_bullet = 1;
	mg_sound = 1;
	gun_sound = 1;
	engine_key = 1;
	fwd_rev = 16;
	left_right = 16;

	printf("\n");
	printf("Palim motor...\n");
	engine_key = 0;
	for (i = 0; i < 200; i++)
		fm_tx();

	printf("Cekam da se zgrije motor...\n");
	engine_key = 1;
	for (i = 0; i < 300; i++)
		fm_tx();
	
	printf("Kupola desno...\n");
	turr_right = 0;
	for (i = 0; i < 100; i++)
		fm_tx();
	turr_right = 1;
	for (i = 0; i < 10; i++)
		fm_tx();

	printf("Kupola lijevo...\n");
	turr_left = 0;
	for (i = 0; i < 100; i++)
		fm_tx();
	turr_left = 1;
	for (i = 0; i < 10; i++)
		fm_tx();

	printf("Gasim motor...\n");
	engine_key = 0;
	for (i = 0; i < 200; i++)
		fm_tx();

	return (0);
}
#endif


#if 1
int
main(void)
{
	int c, speed;

	do {
		/* Bail out to bootloader on CTRL+C */
		c = sio_getchar(0);
		if (c == 3)
			return (0);
		c = random() >> 8;
		OUTB(IO_LED, c);

		INB(c, IO_DIPSW);

		/* Select vechile speed */
		speed = (c & 0xf) >> 2;

		/* Select carrier frequency */
		switch (c & 0x3) {
		case 0:
			dds_base = 349676; /* 325 MHz PLL, 27.095 MHz */
			break;
		case 1:
			dds_base = 350321; /* 325 MHz PLL, 27.145 MHz */
			break;
		default:
			dds_base = 0; /* Do not transmit */
			break;
		}
		
		turr_left = 1;
		turr_right = 1;
		gun_elev = 1;
		gun_bullet = 1;
		mg_sound = 1;
		gun_sound = 1;
		engine_key = 1;
		fwd_rev = 16;
		left_right = 16;

		INB(c, IO_PUSHBTN);
		c &= BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT;
		switch (c) {
		case BTN_LEFT | BTN_CENTER | BTN_RIGHT:
			engine_key = 0;
			break;
		case BTN_UP | BTN_DOWN:
			mg_sound = 0;
			break;
		case BTN_CENTER | BTN_UP:
			gun_sound = 0;
			break;
		case BTN_CENTER | BTN_DOWN:
			gun_elev = 0;
			break;
		case BTN_CENTER | BTN_LEFT:
			turr_left = 0;
			break;
		case BTN_CENTER | BTN_RIGHT:
			turr_right = 0;
			break;
		case BTN_UP:
			fwd_rev = 19 + speed;
			break;
		case BTN_UP | BTN_LEFT:
			fwd_rev = 20 + speed;
			left_right = 19;
			break;
		case BTN_UP | BTN_RIGHT:
			fwd_rev = 20 + speed;
			left_right = 13;
			break;
		case BTN_DOWN:
			fwd_rev = 13 - speed;
			break;
		case BTN_DOWN | BTN_LEFT:
			fwd_rev = 12 - speed;
			left_right = 19;
			break;
		case BTN_DOWN | BTN_RIGHT:
			fwd_rev = 12 - speed;
			left_right = 13;
			break;
		case BTN_LEFT:
			left_right = 23 + speed;
			break;
		case BTN_RIGHT:
			left_right = 9 - speed;
			break;
		default:
			break;
		}

		fm_tx();
	} while (1);
}
#endif
