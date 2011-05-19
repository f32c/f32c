
#ifndef XXX
#include <io.h>
#include <types.h>
#else
#include <sys/types.h>
#endif
#include <stdio.h>


extern void pcm_play(void);

int outw;


static int dds_base = 378816; /* 27.095 MHz */


static void
wait(int len)
{
	static int t0;
	int t1, d;

	do {
		t1 = rdtsc();
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


#define CYCLE 939

static void
fm_tx(void)
{
	int i, t;

	txbit(0, 2 * CYCLE + 250);
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

	 txbit(1, 14 * CYCLE + 250);
}


int
main(void)
{
	int old_c = 0;
	int t, last_break = 0;
	int c;
	// int i;
	
	int fwd_rev, left_right, turr_left, turr_right, gun_elev, gun_bullet;
	int mg_sound, gun_sound, engine_key, csum;

	// sio_idle_fn = fm_tx;

	fwd_rev = 16;
	left_right = 16;

	do {
		do {
			fm_tx();
			INW(c, IO_PUSHBTN);

			t = rdtsc() - last_break;
			if (t < 0)
				t = -t;
			if ((c & BTN_CENTER) && t > 1000000) {
				last_break = rdtsc();
				if (fwd_rev > 24)
					fwd_rev--;
				if (fwd_rev > 16)
					fwd_rev--;
				if (fwd_rev < 8)
					fwd_rev++;
				if (fwd_rev < 16)
					fwd_rev++;
				if (left_right > 16)
					left_right--;
				if (left_right < 16)
					left_right++;
				break;
			}
		} while (c == old_c);
		old_c = c;

		turr_left = 1;
		turr_right = 1;
		gun_elev = 1;
		gun_bullet = 1;
		mg_sound = 1;
		gun_sound = 1;
		engine_key = 1;

		if (c & BTN_CENTER) {
			if ((c & BTN_LEFT) && !(c & BTN_RIGHT))
				turr_left ^= 1;
			if ((c & BTN_RIGHT) && !(c & BTN_LEFT))
				turr_right ^= 1;
			if ((c & BTN_UP) && !(c & BTN_DOWN))
				gun_sound ^= 1;
			if ((c & BTN_DOWN) && !(c & BTN_UP))
				gun_elev ^= 1;
			if ((c & BTN_UP) && (c & BTN_DOWN))
				mg_sound ^= 1;
			if ((c & BTN_LEFT) && (c & BTN_RIGHT))
				engine_key ^= 1;

		} else {
			if ((c & BTN_UP)  && fwd_rev < 31) {
				if (fwd_rev == 16)
					fwd_rev = 19;
				else
					fwd_rev++;
			}
			if ((c & BTN_DOWN) && fwd_rev > 1) {
				if (fwd_rev == 16)
					fwd_rev = 13;
				else
					fwd_rev--;
			}
			if ((c & BTN_LEFT) && left_right < 31) {
				if (left_right == 16)
					left_right = 19;
				else if (left_right == 13)
					left_right = 16;
				else
					left_right++;
			}
			if ((c & BTN_RIGHT) && left_right > 1) {
				if (left_right == 16 )
					left_right = 13;
				else if (left_right == 19 )
					left_right = 16;
				else
					left_right--;
			}
		}

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

#if 0
		printf("fwd_rev:    %d\n", fwd_rev);
		printf("left_right: %d\n", left_right);
		printf("turr_left:  %d\n", turr_left);
		printf("turr_right: %d\n", turr_right);
		printf("gun_elev:   %d\n", gun_elev);
		printf("gun_bullet: %d\n", gun_bullet);
		printf("mg_sound:   %d\n", mg_sound);
		printf("gun_sound:  %d\n", gun_sound);
		printf("engine_key: %d\n", engine_key);
		printf("csum:       %d\n", csum);
		printf("\n");
#endif

#if 0
		printf("fr: %d ", fwd_rev);
		printf("lr: %d ", left_right);
		printf("tl: %d ", turr_left);
		printf("tr: %d ", turr_right);
		printf("ge: %d ", gun_elev);
		printf("gb: %d ", gun_bullet);
		printf("ms: %d ", mg_sound);
		printf("gs: %d ", gun_sound);
		printf("ek: %d ", engine_key);
		printf("\n");
#endif

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

#if 0
		printf("0123456789abcdef0123456789abcdef\n");
		for (c = outw, i = 0; i < 32; i++) {
			if (c & 0x80000000)
				printf("1");
			else
				printf("0");
			c <<= 1;
		}
		printf("\n");
#endif
	} while (1);
}
