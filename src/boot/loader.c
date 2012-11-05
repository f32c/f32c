
#include <sys/param.h>
#include <io.h>


#if _BYTE_ORDER == _BIG_ENDIAN
static char *prompt = "\r\nf32c/be> ";
#elif _BYTE_ORDER == _LITTLE_ENDIAN
static char *prompt = "\r\nf32c/le> ";
#else
#error "Unsupported byte order."
#endif

void *base_addr = NULL;

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
		int hc = (((c) >> 4) & 0xf) + '0';			\
		if (hc > '9')						\
			hc += 'a' - '9' - 1;				\
		pchar(hc);						\
		hc = ((c) & 0xf) + '0';					\
		if (hc > '9')						\
			hc += 'a' - '9' - 1;				\
		pchar(hc);						\
	} while (0)


__dead2
void
_start(void)
{
	int c, cnt, pos, val, len, t;
	char *cp;

	__asm __volatile__(
		".set noreorder;"
		"nop;"			/* just in case... */
		".set reorder;"
	);

boot:
	if (base_addr) {
		cp = (void *) base_addr;
		base_addr = NULL;
		__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"	/* stack mask */
		"lui $5, 0x0010;"	/* top of the initial stack */
		"move $31, $0;"
		"and $29, %0, $4;"	/* clear low bits of the stack */
		"jr %0;"
		"or $29, $29, $5;"	/* set stack */
		".set reorder;"
		: 
		: "r" (cp)
		);
	}

prompt:
	for (cp = prompt; *cp != 0; cp++)
		pchar(*cp);

next:
	pos = -1;
	cp = 0;
	len = 255;
	val = 0;
	cnt = 2;

loop:
	/* Blink LEDs while waiting for serial input */
	do {
		RDTSC(t);
		if (t & 0x08000000)
			c = 0xff;
		else
			c = 0;
		if ((t & 0xff) > ((t >> 19) & 0xff))
			OUTB(IO_LED, c ^ 0x0f);
		else
			OUTB(IO_LED, c ^ 0xf0);
		INB(c, IO_SIO_STATUS);
	} while ((c & SIO_RX_FULL) == 0);
	INB(c, IO_SIO_BYTE);

	if (pos < 0) {
		if (c == 'S')
			pos = 0;
		else {
			if (c == '\r') /* CR ? */
				goto prompt;
			/* Echo char */
			pchar(c);
		}
		goto loop;
	}
	if (c == '\r') /* CR ? */
		goto next;

	val <<= 4;
	if (c >= 'a')
		c -= 32;
	if (c >= 'A')
		val |= c - 'A' + 10;
	else
		val |= c - '0';
	pos++;

	/* Address width */
	if (pos == 1) {
		if (val == 9)
			goto boot;
		if (val >= 1 && val <= 3)
			len = (val << 1) + 5;
		val = 0;
		goto loop;
	}

	/* Byte count */
	if (pos == 3) {
		cnt += (val << 1);
		val = 0;
		goto loop;
	}

	/* End of address */
	if (pos == len) {
		cp = (char *) val;
		if (base_addr == NULL)
			base_addr = (void *) val;
		goto loop;
	}

	if (pos > len && (pos & 1) && pos < cnt)
		*cp++ = val;

	goto loop;
	/* Unreached */
}
