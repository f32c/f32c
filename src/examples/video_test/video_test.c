/*
 * Exercise various graphics manipulation functions.  Apparently also
 * a good test for S(D)RAM consistency / reliability.
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <dev/io.h>
#include <dev/fb.h>
#include <sys/isr.h>
#include <mips/asm.h>


static uint32_t ink, freq_khz, tsc_hi, tsc_lo;
static char buf[64];


static int
tsc_update(void)
{
	int32_t tsc;

	/* Clear the 50 Hz framebuffer interrupt */
	INB(tsc, IO_FB);

	RDTSC(tsc);
	if (tsc < tsc_lo)
		tsc_hi++;
	tsc_lo = tsc;
	OUTB(IO_LED, tsc >> 20);

	/*
	 * tsc_update() executes in interrupt context, and as such it
	 * should not use MULT / MULTU, but fb_text() does.  In this
	 * particular program, by pure luck this seems not to be a problem,
	 * but in general, interrupt context routines should be more
	 * carefully crafted to avoid messing up HI and LO registers.
	 */
	fb_text(38, 228, buf, 0, -1, 3);
	fb_text(35, 225, buf, ink, -1, 3);
	fb_text(180, 260, buf, ink, 0, 0);

	return (1);
}


static struct isr_link fb_isr = {
	.handler_fn = &tsc_update
};


static uint32_t
ms_uptime(void)
{
	uint64_t tsc64;

	tsc64 = tsc_hi;
	tsc64 <<= 32;
	tsc64 += tsc_lo;
	return(tsc64 / freq_khz);
}


void
main(void)
{
	int i, rep, tmp, mode = 0;
	uint32_t start, end;
	uint32_t x0, y0, x1, y1;

	isr_register_handler(2, &fb_isr);
	asm("ei");

	freq_khz = (get_cpu_freq() + 499) / 1000;

again:
	fb_set_mode(mode);
	ink = fb_rgb2pal(0xffffff);	/* white */

	/* Lines */
	for (rep = 0; rep < 20; rep++) {
		start = ms_uptime();
		for (i = 0; i < 10000; i++) {
			tmp = random();
			x0 = tmp & 0x1ff;
			y0 = (tmp >> 8) & 0xff;
			x1 = (tmp >> 16) & 0x1ff;
			y1= (tmp >> 24) & 0xff;
			fb_line(x0, y0, x1, y1, i ^ tmp);
		}
		end = ms_uptime();
		tmp = i * 1000 / (end - start);
		sprintf(buf, " mode %d: %u lines / s ", mode, tmp);
		printf("%s\n", buf);

		if (sio_getchar(0) == 3)
			exit(0); /* CTRL+C */
	}

	mode ^= 1;
	goto again;
}
