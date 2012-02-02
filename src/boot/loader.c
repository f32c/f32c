
#include <types.h>
#include <endian.h>
#include <io.h>


#define BOOTADDR	0x000001a0


#if _BYTE_ORDER == _BIG_ENDIAN
static char *prompt = "\r\nf32c/be> ";
#elif _BYTE_ORDER == _LITTLE_ENDIAN
static char *prompt = "\r\nf32c/le> ";
#else
#error "Unsupported byte order."
#endif

int cold_boot = 1;


#define	pchar(c)							\
	do {								\
		int s;							\
									\
		do {							\
			INB(s, IO_SIO_STATUS);				\
		} while (s & SIO_TX_BUSY);				\
		OUTB(IO_SIO_BYTE, (c));					\
	} while (0)


__attribute__((noreturn)) void
_start(void)
{
	int c, pos, val, len;
	char *cp;

	__asm __volatile__(
		".set noreorder;"
		"nop;"
		"li $29, (0x80000000);"
		".set reorder;"
	);

	if (cold_boot) {
boot:
		cold_boot = 0;
		__asm __volatile__(
			".set noreorder;"
			"j %0;"
			"move $31, $0;"
			".set reorder;"
			:
			: "i" (BOOTADDR)
		);
	}

prompt:
	for (cp = prompt; *cp != 0; cp++)
		pchar(*cp);

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
		pchar(c);

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
