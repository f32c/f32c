/*
 * Exercise various graphics manipulation functions.  Apparently also
 * a good test for SRAM consistency / reliability.
 *
 * $Id$
 */

#include <stdio.h>
#include <stdlib.h>
#include <io.h>
#include <fb.h>
#include <sys/isr.h>
#include <mips/asm.h>


static uint32_t freq_khz, tsc_hi, tsc_lo;
static char buf[64];


/*
 * tsc_update() executes in interrupt context, must not use MULT / MULTU! */
 */
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

	fb_text(180, 260, buf, -1, 0, 0);
	fb_text(180, 140, buf, -1, 0, 0);

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

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);

again:
	fb_set_mode(mode);

	/* Lines */
	for (rep = 0; rep < 10; rep++) {
		start = ms_uptime();
		for (i = 0; i < 20000; i++) {
			tmp = random();
			x0 = tmp & 0x1ff;
			y0 = (tmp >> 8) & 0xff;
			x1 = (tmp >> 16) & 0x1ff;
			y1= (tmp >> 24) & 0xff;
			fb_line(x0, y0, x1, y1, i);
		}
		end = ms_uptime();
		tmp = i * 1000 / (end - start);
		sprintf(buf, " mode %d: %u lines / s ", mode, tmp);
		printf("%s\n", buf);
	}

	mode ^= 1;
	goto again;
}
