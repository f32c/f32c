/*
 * Print a message on serial console, and blink LEDs until a button
 * is pressed on the ULX2S FPGA board.
 *
 * $Id: hello.c 1693 2013-11-25 23:14:31Z marko $
 */

extern "C" {
#include <stdio.h>
#include <io.h>
}


class Hello {
public:
	Hello();
	void message();
private:
	int	_initialized;
};


Hello::Hello() : _initialized(1)
{
};


void
Hello::message()
{

	printf("Hello from C++, object %p, initialized = %d\n", this,
	    _initialized);
};


Hello hello_global;


void
main(void)
{
	int in, out = 0;

	printf("Hello, FPGA world!\n");

	do {
		OUTB(IO_LED, out >> 20);
		out++;
		hello_global.message();
		INB(in, IO_PUSHBTN);
	} while (in == 0);
}
