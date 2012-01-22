
#include <types.h>
#include <io.h>


#define BOOTADDR	0x00000180


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
loop:
	/* Blink LEDs while waiting for serial input */
	do {
		INW(val, IO_TSC);
		INB(c, IO_SIO_STATUS);
		OUTB(IO_LED, val >> 20);
	} while ((c & SIO_RX_FULL) == 0);
	INB(c, IO_SIO_BYTE);

	/* X ? */
	if (c == 'x')
		goto boot;

	/* CR ? */
	if (c == '\r') {
		for (cp = prompt; *cp != 0; cp++) {
			do {
				INB(val, IO_SIO_STATUS);
			} while (val & SIO_TX_BUSY);
			OUTB(IO_SIO_BYTE, *cp);
		}
		goto loop;
	}

	if (c != ':') {
		/* Echo char */
		do {
			INB(val, IO_SIO_STATUS);
		} while (val & SIO_TX_BUSY);
		OUTB(IO_SIO_BYTE, c);
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

		if (c == '\r')
			goto loop;

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
		if (pos == 7 && (val & 0xff) == 1)
			goto boot;

		/* Data */
		if ((pos & 1) && pos > 8 && pos < len)
			*cp++ = val;

		pos++;
	} while (1);

	/* Unreached */
}
