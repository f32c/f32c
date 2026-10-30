/*
 * Print a message on serial console and blink LEDs until a button is pressed.
 */

#include <stdio.h>
#include <unistd.h>

#include <dev/io.h>

#ifdef __mips__
#define	ARCH	"mips"
#elif defined(__riscv)
#define	ARCH	"riscv"
#else
#define	ARCH	"unknown"
#endif

#define	BTN_ANY	(BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)


void
main(void)
{
	int in, out = 0;

	do {
		OUTB(IO_LED, out++);
		printf("Hello, f32c/%s world! iter %d\n", ARCH, out);
		sleep(1);
		INB(in, IO_PUSHBTN);
	} while ((in & BTN_ANY) == 0);
}
