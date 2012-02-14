
#include <sys/param.h>
#include <mips/endian.h>
#include <sys/stdint.h>
#include <io.h>


#define MONITOR

#ifdef MONITOR
#define BOOTADDR	0x00000400
#else
#define BOOTADDR	0x000001a0
#endif


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


#define	phex(c)								\
	do {								\
									\
		hc = (((c) >> 4) & 0xf) + '0';				\
		if (hc > '9')						\
			hc += 'a' - '9' - 1;				\
		pchar(hc);						\
		hc = ((c) & 0xf) + '0';					\
		if (hc > '9')						\
			hc += 'a' - '9' - 1;				\
		pchar(hc);						\
	} while (0)


__dead2 void
_start(void)
{
	int c, pos, val, len;
	char *cp;
#ifdef MONITOR
	int hc;
	int dumpmode = 0;
	uint8_t *dumpaddr = NULL;
#endif

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
#ifdef MONITOR
	for (dumpmode &= 0xff; dumpmode > 0; dumpmode--) {
		pchar('\r');
		pchar('\n');

		/* addr */
		val = (int) dumpaddr;
		for (pos = 4; pos; pos--) {
			phex(val >> 24);
			val <<= 8;
		}

		/* hex */
		for (pos = 0;; pos++) {
			if ((pos & 0x7) == 0)
				pchar(' ');
			pchar(' ');
			if (pos == 16)
				break;
			phex(dumpaddr[pos]);
		}

		/* ASCII */
		for (pos = 16; pos; pos--) {
			val = *dumpaddr++;
			if (val < 32 || val > 126)
				val = '.';
			pchar(val);
		}
	}
#endif

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

		if (c == 's')
			goto boot;

		if (c == 'X') {
			dumpmode = 0x100 + 16;
			goto prompt;
		}

		if (c == 'x')
			dumpmode = 0x100 + 16;

		if (dumpmode &&
		    ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
			if (dumpmode & 0x100)
				dumpaddr = NULL;
			dumpmode &= 0xff;
			if (c & 0x40)
				val = c - 'a' + 10;
			else
				val = c - '0';
			dumpaddr = (void *) (((int) dumpaddr << 4) | val);
		}

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
