
#include <sio.h>

int
main(void)
{
	register int c;

	do {
		c = sio_getchar();
		sio_putchar(c);
	} while (1);
}

