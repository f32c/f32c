
#include <types.h>
#include <io.h>


#define BOOTADDR	0x000001a0


static char *prompt = "\r\nf32c> ";
int cold_boot = 1;


__attribute__((noreturn)) void
_start(void)
{
	int c, pos, val, len;
	char *cp;

	if (cold_boot) {
boot:
		cold_boot = 0;
		__asm __volatile__(
			".set noreorder;"
			"li $29, (0x80000000);"
			"j %0;"
			"move $31, $0;"
			".set reorder;"
			:
			: "i" (BOOTADDR)
		);
	}

prompt:
	for (cp = prompt; *cp != 0; cp++) {
		do {
			INB(val, IO_SIO_STATUS);
		} while (val & SIO_TX_BUSY);
		OUTB(IO_SIO_BYTE, *cp);
	}

loop:
	/* Blink LEDs while waiting for serial input */
	do {
		INW(val, IO_TSC);
		INB(c, IO_SIO_STATUS);
		OUTB(IO_LED, val >> 20);
	} while ((c & SIO_RX_FULL) == 0);
	INB(c, IO_SIO_BYTE);

	/* CR ? */
	if (c == '\r')
		goto prompt;

	if (c != ':') {
		/* Echo char */
		do {
			INB(val, IO_SIO_STATUS);
		} while (val & SIO_TX_BUSY);
		OUTB(IO_SIO_BYTE, c);

		/* X ? */
		if (c == 'x')
			goto boot;

		goto loop;
	}

	pos = 0;
	cp = 0;
	len = 0;
	do {
		/* Wait for serial input */
		do {
			INB(c, IO_SIO_STATUS);
		} while ((c & SIO_RX_FULL) == 0);
		INB(c, IO_SIO_BYTE);

		if (c == '\r') {
			if (len < 0)
				goto boot;
			else
				goto loop;
		}

		val <<= 4;
		if (c >= 'a')
			c -= 32;
		if (c >= 'A')
			val |= c - 'A' + 10;
		else
			val |= c - '0';

		/* Byte count */
		if (pos == 1)
			len = ((val & 0xff) << 1) + 8;

		/* Address */
		if (pos == 5)
			cp = (char *) (val & 0xffff);

		/* Record type - only type 0 contains valid data */
		if (pos == 7 && (val & 0xff) != 0) {
			if ((val & 0xff) == 1) /* EOF marker */
				len = -1; /* boot after receiving a CR char */
			else
				len = 0;
		}

		/* Data */
		if ((pos & 1) && pos > 8 && pos < len)
			*cp++ = val;

		pos++;
	} while (1);

	/* Unreached */
}
