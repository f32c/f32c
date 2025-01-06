/*
 * Enable timer interrupts at INTR_FREQ, and report status each second.
 * Toggle every 4 seconds between waiting for interrupts using a dedicated
 * CPU instruction or simply looping until a full second expires.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dev/io.h>
#include <sys/isr.h>
#include <sys/task.h>

#include <mips/asm.h>


#define	INTR_FREQ 100000

#define BTN_ANY (BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)

static uint32_t tick_incr;
static uint32_t cnt0;

static int
tsc_update(void)
{
	uint32_t next_t;

	mfc0_macro(next_t, MIPS_COP_0_COMPARE);
	next_t += tick_incr;
	mtc0_macro(next_t, MIPS_COP_0_COMPARE);
	cnt0++;
	curthread_set((void *) cnt0);

	return (1);
}


static struct isr_link tick_isr = {
	.handler_fn = &tsc_update
};


void
main(void)
{
	int tmp, in;
	int sec = 0, prev_sec = 0;
	int cnt1 = 0;
	int loopc = 0;
	int waitc = 0;

	tick_incr = get_cpu_freq() / INTR_FREQ;

	isr_register_handler(7, &tick_isr);
	asm("ei");

	do {
		INW(sec, IO_RTC_UPTIME_S);
		if (sec != prev_sec) {
			OUTB(IO_LED, sec);
//			printf("Freq %f MHz, ", get_cpu_freq() / 1000000.0);
			printf("td %p, ", curthread);
			printf("up %d s, intr / s %d, loops / s %d, "
			    "waits / s %d\n", sec, cnt0 - cnt1,
			    loopc, waitc);
			if (cnt0 == cnt1) {
				mfc0_macro(tmp, MIPS_COP_0_COUNT);
				tmp += tick_incr;
				mtc0_macro(tmp, MIPS_COP_0_COMPARE);
			}
			prev_sec = sec;
			cnt1 = cnt0;
			loopc = 0;
			waitc = 0;
		}
		if (sec & 4 && cnt0 != cnt1) {
			asm("wait");
			waitc++;
		}
		loopc++;
		INB(in, IO_PUSHBTN);
	} while ((in & BTN_ANY) == 0);

	asm("di");
	isr_remove_handler(7, &tick_isr);
}
