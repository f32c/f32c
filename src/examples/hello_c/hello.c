/*
 * Print a message on serial console, and blink LEDs until a button
 * is pressed on the ULX2S FPGA board.
 *
 * $Id$
 */

#include <stdio.h>
#include <io.h>

#ifdef __mips__
static const char *arch = "mips";
#elif defined(__riscv__)
static const char *arch = "riscv";
#else
static const char *arch = "unknown";
#endif

void
main(void)
{
	int in, out = 0;

	printf("Hello, f32c/%s world!\n", arch);

	do {
		OUTB(IO_LED, out >> 20);
		out++;
		INB(in, IO_PUSHBTN);
	} while (in == 0);
}
