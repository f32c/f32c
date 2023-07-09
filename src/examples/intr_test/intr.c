/*
 * Print out something each 1/2 second from interrupt context.  Even after
 * the program terminates once a button gets pressed, interrupts remain
 * enabled so messages will continue to be displayed while the bootloader
 * processes serial input.
 */

#include <stdio.h>
#include <string.h>
#include <time.h>
#include <dev/io.h>
#include <sys/isr.h>
#include <mips/asm.h>


#define BTN_ANY (BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)

static uint32_t next_t, freq_khz, tsc_lo;


static int
tsc_update(void)
{
	int32_t tsc;

	mfc0_macro(tsc, MIPS_COP_0_COUNT);

	printf("%d ticks passed since the last interrupt.\n", tsc - tsc_lo);

	tsc_lo = tsc;

	next_t = next_t + freq_khz * 500;
	mtc0_macro(next_t, MIPS_COP_0_COMPARE);

	return (1);
}


static struct isr_link tick_isr = {
	.handler_fn = &tsc_update
};


void
main(void)
{
	int tmp, in, out = 0;

	freq_khz = (get_cpu_freq() + 499) / 1000;
	printf("Clock ticks at %f MHz.\n", freq_khz / 1000.0);

	mfc0_macro(tmp, MIPS_COP_0_COUNT);
	next_t = tmp + freq_khz * 500;
	mtc0_macro(next_t, MIPS_COP_0_COMPARE);

	isr_register_handler(7, &tick_isr);
	asm("ei");

	do {
		OUTB(IO_LED, out++);
		asm("wait");
		INB(in, IO_PUSHBTN);
	} while ((in & BTN_ANY) == 0);
}
