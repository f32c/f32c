
#include <types.h>
#include <io.h>
#include <sio.h>

static char *msg = "\n\rFER ULXP2 board rev 0; f32c core\r\n";

int
main(void)
{
	int c;
	char *cp;
	
	do {
		c = sio_getchar();

		if (c == '\r') {
			for (cp = msg; *cp != 0; cp++)
				sio_putchar(*cp);
			continue;
		}

		// Convert to upper case
		if (c >= 'a' && c <= 'z')
			c -= 32;

		sio_putchar(c);
	} while (1);
}

