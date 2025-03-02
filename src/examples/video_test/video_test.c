/*
 * Exercise various graphics manipulation functions.  Apparently also
 * a good speed test for combined read / write SDRAM throughput.
 *
 * Scores reported on the serial console are relative to the ULX3S board
 * with sdram_dv design @ 90 MHz, * using the standard sdram controller,
 * with the vidtest binary built using gcc-13.2.
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <dev/io.h>
#include <dev/fb.h>

typedef void test_fn_t(int, int, int, int, int);

static void
circle_test(int x0, int y0, int x1, int y1, int ink)
{

	fb_filledcircle(x0, y0, (x1 ^ y0) & 0x7f, ink);
}

static void
text_test(int x0, int y0, int x1, int y1, int ink)
{

	fb_text(x0, y0, "Hello, f32c world!", ink, ink >> 16,
	    ((x0 & 0x7) << 16) + (y0 & 0x7));
}

struct fb_test {
	test_fn_t *fn;
	char *desc;
	uint32_t weight;
	uint64_t time;
} fb_test[] = {
	{ .fn = fb_line, .desc = "lines", .weight = 3133 },
	{ .fn = fb_rectangle, .desc = "rects", .weight = 410 },
	{ .fn = circle_test, .desc = "circles", .weight = 2500 },
	{ .fn = text_test, .desc = "text", .weight = 205 },
	{ /* terminate list */ }
};

void
main(void)
{
	int ti = 0, iter = 1;
	int i, rnd;
	struct timespec start, end;
	uint32_t x0, y0, x1, y1;
	uint64_t ips, score, overall = 0;

	fb_set_mode(FB_MODE_1080i60, FB_BPP_8);
	printf("\nresults are relative to FB_MODE_1080i60, FB_BPP_8"
	    " at 90 MHz CPU clock\n\n");

	printf("Allow at least 15 iterations (cca 1 minute) "
	    "for the scores to start converging\n\n");

	do {
		OUTB(IO_LED, (iter << 2) + ti);
		if (ti == 0)
			printf("iter #%d: ", iter);
		clock_gettime(CLOCK_MONOTONIC, &start);
		for (i = 0; i < fb_test[ti].weight; i++) {
			RDTSC(rnd);
			rnd += random();
			x0 = rnd % fb_hdisp;
			y0 = (rnd >> 10) % fb_vdisp;
			rnd += start.tv_nsec;
			x1 = (rnd >> 8) % fb_hdisp;
			y1 = (rnd >> 18) % fb_vdisp;
			fb_test[ti].fn(x0, y0, x1, y1, rnd);
		}
		clock_gettime(CLOCK_MONOTONIC, &end);
		fb_test[ti].time += end.tv_nsec - start.tv_nsec
		    + (end.tv_sec - start.tv_sec) * 1000000000ULL;
		ips = i * 1000000000ULL * iter / fb_test[ti].time;
		score = ips * 1000 / fb_test[ti].weight;
		overall += score;
		score += 5;
		printf("%s: %llu.%02llu ", fb_test[ti].desc, score / 1000,
		    (score / 10) % 100);

		ti++;
		if (fb_test[ti].fn == NULL) {
			overall /= ti;
			overall += 5;
			printf("overall: %llu.%02llu\n", overall / 1000,
			    (overall / 10) % 100);
			ti = 0;
			overall = 0;
			iter++;
		}
	} while (sio_getchar(0) != 3); /* CTRL+C */
}
