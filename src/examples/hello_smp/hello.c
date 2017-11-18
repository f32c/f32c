/*
 * Print a message on serial console and blink LEDs until a button is pressed.
 *
 * $Id$
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dev/io.h>
#include <dev/sio.h>

#include <mips/asm.h>
#include <mips/cpuregs.h>

#ifdef __mips__
static const char *arch = "mips";
#elif defined(__riscv)
static const char *arch = "riscv";
#else
static const char *arch = "unknown";
#endif

#define	BTN_ANY	(BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)


void
main(void)
{
	int in, out = 0;
	uint32_t tmp, cpuid;
	char c;

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	cpuid = tmp & 0xf;

	if (cpuid == 0) {
		/* Wake up all CPUs */
		printf("Hello, f32c/%s world!\n", arch);
		OUTB(IO_CPU_RESET, 0);
	}

	if (cpuid == 4) {
		OUTB(IO_CPU_RESET, 1);
	}

#if 1
	tmp = 0x80180000 + 0x1000 * cpuid;
	__asm __volatile__(
		"move $29, %0;"	/* set SP */
		:
		: "r" (tmp)
	);
#endif

	/* It's a mystery why we need this to fire up CPU #3 */
	OUTB(IO_CPU_RESET, 0);

	tmp = 1 << cpuid;
	do {
		INB(in, IO_PUSHBTN);
		if ((in & BTN_ANY) == 0)
			OUTB(IO_LED, tmp);
		out += (cpuid + 13);
		if (out > 0x1000000) {
			OUTB(IO_SIO_BYTE, ' ');
			do {
				INB(c, IO_SIO_STATUS);
			} while (c & SIO_TX_BUSY);
			c = '0' + cpuid;
			out = 0;
			OUTB(IO_SIO_BYTE, c);
		}
	} while (1);
}
