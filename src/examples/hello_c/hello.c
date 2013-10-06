/*
 * Print a message on serial console, and blink LEDs until a button
 * is pressed on the ULX2S FPGA board.
 *
 * $Id $
 */

#include <sys/param.h>
#include <stdio.h>
#include <io.h>

void
main(void)
{
	int in, out = 0;

	printf("Hello, FPGA world!\n");

	do {
		OUTB(IO_LED, out >> 20);
		out++;
		INB(in, IO_PUSHBTN);
	} while (in == 0);
}
