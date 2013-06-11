
#include <sys/param.h>
#include <io.h>


#if _BYTE_ORDER == _BIG_ENDIAN
static char *prompt = "\r\nf32c/be> ";
#elif _BYTE_ORDER == _LITTLE_ENDIAN
static char *prompt = "\r\nf32c/le> ";
#else
#error "Unsupported byte order."
#endif

#define	BOOTADDR	0x0220


void *base_addr = (void *) BOOTADDR;

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
	int c, cnt, pos, val, len;
	char *cp;

	__asm __volatile__(
		"move $31, $0;"
	);

	if (base_addr) {
		cp = (void *) base_addr;
boot:
		base_addr = NULL;
		__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"	/* stack mask */
		"lui $5, 0x0010;"	/* top of the initial stack */
		"and $29, %0, $4;"	/* clear low bits of the stack */
		"jr %0;"
		"or $29, $29, $5;"	/* set stack */
		".set reorder;"
		: 
		: "r" (cp)
		);
	}

	/* Flush I-cache, clear DRAM */
	for (cp = (void *) 0x80000000; cp < (char *) 0x80100000;  cp += 4) {
		__asm (
			"cache	0, 0(%0);"
			"sw	$0, 0(%0)"
			:
			: "r" (cp)
		);
	}

prompt:
	cp = prompt;
	do {
		c = *cp++;
pchar:
		pchar(c);
	} while (*cp != 0);

next:
	pos = -1;
	len = 255;
	cnt = 2;

loop:
	/* Blink LEDs while waiting for serial input */
	do {
		if (pos < 0) {
			RDTSC(val);
			if (val & 0x08000000)
				c = 0xff;
			else
				c = 0;
			if ((val & 0xff) > ((val >> 19) & 0xff))
				OUTB(IO_LED, c ^ 0x0f);
			else
				OUTB(IO_LED, c ^ 0xf0);
		} else
			OUTB(IO_LED, (int) cp >> 8);
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
			goto pchar;
		}
		val = 0;
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
		if (val >= 7 && val <= 9) {
			if (base_addr != NULL)
				cp = base_addr;
			else
				cp = (void *) BOOTADDR;
			goto boot;
		}
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
