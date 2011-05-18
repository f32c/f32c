
#ifndef XXX
#include <io.h>
#include <types.h>
#else
#include <sys/types.h>
#endif
#include <stdio.h>


extern void pcm_play(void);


int
main(void)
{
	int c, cnt;
	int *tsc;
	
#ifndef XXX
	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;
	tsc = (int *) 0x000001fc;
#else
	system("stty -echo -icanon -iexten");
	tsc = &c;
#endif

#if 1
#define MAPSIZE 160
	int map[MAPSIZE];
	char cmap[MAPSIZE * 2];
	char ocmap[MAPSIZE * 2];
	char *cp, *ocp;
	int i, old, ts, tlen, state;

	i = 0;
	old = 0;
	ts = 0;
	state = 0;
	cp = cmap;

	int fwd_rev, left_right, turr_left, turr_right, gun_elev, gun_bullet;
	int mg_sound, gun_sound, engine_key, csum, csum1;

	do {
		do {
			INB(c, IO_PUSHBTN + 2);
		} while (c == old);
		old = c;
		tlen = ts;
		ts = rdtsc();
		tlen = ts - tlen;
		if (tlen < 0)
			tlen = -tlen;
		c = (c & 1);

		if (state == 0) {
			if (c == 1 && tlen > 10000)
				state = 1;
			continue;
		}

		if (state == 1) {
			if (c == 0 && tlen > 3000 && tlen < 3500)
				state = 2;
			continue;
		}

#if 0
		if (state < 13) {
			if (tlen > 700 && tlen < 1300)
				state++;
			else
				state = 0;
			continue;
		}

		if (state == 13) {
			if (tlen > 1500 && tlen < 2200)
				state++;
			else
				state = 0;
			continue;
		}

		if (state < 16) {
			if (tlen > 600 && tlen < 1200)
				state++;
			else
				state = 0;
			continue;
		}
#endif

		if (c)
			*cp++ = '1';
		else
			*cp++ = '0';
		if (tlen > 1500) {
			if (c)
				*cp++ = '1';
			else
				*cp++ = '0';
		}

		if (c)
			map[i] = tlen | 0x80000000;
		else
			map[i] = tlen;
		i++;

		if (tlen > 5000 || i == MAPSIZE) {
#if 0
			c = i;
			for (i = 0; i < c; i++)
				printf("%4d %1d %d us (%d ticks)\n", i,
				    (map[i] & 0x80000000) != 0,
				    (map[i] & 0x7fffffff) * 320 / 1000,
				    map[i] & 0x7fffffff);
			i = 0;
#endif

			*cp = 0;
			//printf("%s\n", cmap);

			c = 0;
			for (cp = cmap, ocp = ocmap; *cp != 0; cp++, ocp++) {
				if (*cp != *ocp)
					c = 1;
				*ocp = *cp;
			}
			
			if (c) {
				printf("\n0123456789abcdef0123456789abcdef\n");
				for (cp = cmap; *cp != 0; cp++) {
					if (((int) cp & 1) == 0)
						continue;
					printf("%c", *cp);
				}
				printf("\n\n");

#define RB(x)	(cmap[((x) * 2) + 1] == '1')
				fwd_rev = RB(8) * 16 + RB(9) * 8 +
				    RB(10) * 4 + RB(11) * 2 + RB(12);
				left_right = RB(18) * 16 + RB(19) * 8 +
				    RB(20) * 4 + RB(21) * 2 + RB(22);
				csum = RB(25) * 8 + RB(26) * 4 +
				     RB(27) * 2 + RB(28);
				turr_left = RB(15);
				turr_right = RB(14);
				gun_elev = RB(16);
				gun_bullet = RB(17);
				mg_sound = RB(24);
				gun_sound = RB(13);
				engine_key = RB(23);

				csum1 = 4;

				csum1 ^= mg_sound;
				csum1 ^= 2 * gun_sound;
				csum1 ^= 2 * engine_key;
				csum1 ^= 2 * gun_bullet;
				csum1 ^= 4 * gun_elev;
				csum1 ^= 8 * turr_left;
				csum1 ^= turr_right;

				csum1 ^= fwd_rev << 2;
				csum1 ^= ((fwd_rev & 0xfc) >> 2);

				csum1 ^= left_right;
				csum1 ^= (left_right >> 4);

				csum1 &= 0xf;

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
				printf("csum1:      %d\n", csum1);
			}
			cp = cmap;

			state = 0;

			continue;
			c = getchar();
			/* Exit to bootloader on CTRL+C */
			if (c == 3)
				return(0);
		}

	} while (1);
#endif

	/*
	 *  12.5 MHz tsc = 62508 div =  106
	 *  25.0 MHz tsc = 31254 div =  211
	 *  75.0 MHz tsc = 10418 div =  632
	 * 150.0 MHz tsc =  5209 div = 1264
	 */

	for (cnt = 0, c = '\r'; cnt < 100000; cnt++) {

		if (c == '\r' || c == '\n') {

			printf("\n");
			printf("Hello, world!\n");
			printf("\n f32c CPU running at %d Hz\n",
			    (75000000 / *tsc) * 10418);
			printf("\n tsc = %d\n", *tsc);
			printf("  %%\n");
			printf("  s: %s\n", "Hello, world!");
			printf("  c: %c\n", '0' + (cnt & 0x3f));
			printf("  d: cnt = %d (neg %d)\n", cnt, -cnt);
			printf(" 8d: cnt = %8d (neg %8d)\n", cnt, -cnt);
			printf("08d: cnt = %08d (neg %08d)\n", cnt, -cnt);
			printf("  u: cnt = %u (neg %u)\n", cnt, -cnt);
			printf("  x: cnt = %x (neg %x)\n", cnt, -cnt);
			printf(" 8x: cnt = %8x (neg %8x)\n", cnt, -cnt);
			printf("08x: cnt = %08x (neg %08x)\n", cnt, -cnt);
			printf("  o: cnt = %o (neg %o)\n", cnt, -cnt);
			printf("  p: cnt = %p\n", &cnt);
		}

		c = getchar();

		/* Exit to bootloader on CTRL+C */
		if (c == 3)
			return(0);

		putchar(c);

		if (c == 'r')
			for (c = 0; c < 10000; c++)
				putchar('.');
	}

	return (0);
}
