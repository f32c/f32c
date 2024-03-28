/*
 * Exercise various graphics manipulation functions.  Apparently also
 * a good test for S(D)RAM consistency / reliability.
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <dev/fb.h>


void
main(void)
{
	int i, rep, tmp, lim, mode = 0;
	struct timespec start, end;
	uint32_t x0, y0, x1, y1;
	uint64_t tdelta;

again:
	fb_set_mode(mode);

	/* Lines */
	for (rep = 0; rep < 15; rep++) {
		clock_gettime(CLOCK_MONOTONIC, &start);
		if (rep < 5)
			lim = 10000;
		else
			lim = 1000;
		for (i = 0; i < lim; i++) {
			tmp = random();
			x0 = tmp & 0x1ff;
			y0 = (tmp >> 8) & 0xff;
			x1 = (tmp >> 16) & 0x1ff;
			y1= (tmp >> 24) & 0xff;
			if (rep < 5)
				fb_line(x0, y0, x1, y1, i ^ tmp);
			else if (rep < 10)
				fb_rectangle(x0, y0, x1, y1, i ^ tmp);
			else
				fb_filledcircle(x0, y0, x1 & 0x7f, i ^ tmp);
		}
		clock_gettime(CLOCK_MONOTONIC, &end);
		tdelta = end.tv_nsec - start.tv_nsec
		    + (end.tv_sec - start.tv_sec) * 1000000000;
		tmp = i * 1000 / (tdelta / 1000000);
		printf(" mode %d: %u ", mode, tmp);
		if (rep < 5)
			printf("lines / s\n");
		else if (rep < 10)
			printf("rectangles / s\n");
		else
			printf("circles / s\n");

		if (sio_getchar(0) == 3)
			exit(0); /* CTRL+C */
	}

	mode ^= 1;
	goto again;
}
