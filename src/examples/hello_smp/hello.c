/*
 * Print a message on serial console and blink LEDs until a button is pressed.
 *
 * $Id$
 */

#include <stdio.h>
#include <string.h>
#include <dev/io.h>

#include <mips/asm.h>
#include <mips/cpuregs.h>

#ifdef __mips__
static const char *arch = "mips";
#elif defined(__riscv__)
static const char *arch = "riscv";
#else
static const char *arch = "unknown";
#endif

#define	BTN_ANY	(BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)


void
main(void)
{
	int in, out = 0;
	int tmp, cpuid;

        mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	cpuid = tmp & 0xf;

	if (cpuid == 0) {
		printf("Hello, f32c/%s world!\n", arch);
		/* Wake up other CPUs, and exit */
		OUTW(IO_CPU_RESET, 0);
	} else do {
		OUTB(IO_LED, out >> 20);
		out++;
		INB(in, IO_PUSHBTN);
	} while ((in & BTN_ANY) == 0);
}
