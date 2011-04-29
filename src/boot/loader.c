
#include <types.h>
#include <io.h>
#include <sio.h>


typedef int mainfn_t(void);


#define CPUFREQ_ADDR	0x000001fc
#define DEF_BOOTADDR	0x00000200


void
_start(void)
{
	mainfn_t *bootaddr;
	int *loadaddr;
	int cur_bits;
	int cur_word;
	int c, cnt, tsc;
	char *cp;
	
	/* Set up IO base address */
	__asm __volatile__(
		"li $27, %0"
		:
		: "i" (IO_BASE)
	);

	/* Determine CPU clock rate, set SIO baud rate to 115200 */
        OUTH(IO_SIO_BAUD, 25000);
        do {
                INW(c, IO_SIO);
        } while (c & SIO_TX_BUSY);
        tsc = rdtsc();
        OUTB(IO_SIO, c);
        do {
                INW(c, IO_SIO);
        } while (c & SIO_TX_BUSY);
        tsc -= rdtsc();
        if (tsc < 0)
                tsc = -tsc;
        for (cnt = 0, c = 0; cnt < 62000; cnt += tsc)
                c += 108;
        OUTH(IO_SIO_BAUD, c); 

	loadaddr = (void *) CPUFREQ_ADDR;
	c = *loadaddr;
	*loadaddr = tsc;
	if (c)
		bootaddr = NULL;
	else {
defaultboot:
		bootaddr = (void *) DEF_BOOTADDR;
	}

	goto start;

	do {
		do {
			INW(c, IO_TSC);
			OUTB(IO_LED, c >> 20);
			INW(c, IO_SIO);
		} while ((c & SIO_RX_BYTES) == 0);
		c = (c >> 8) & 0xff;

		if (bootaddr == NULL && loadaddr == NULL)
			OUTB(IO_SIO, c);

		if (c == '\r') {
			if (loadaddr == NULL) {
start:
				if (bootaddr != NULL) {
					/*
					 * Start main() with a clean stack,
					 * and return address set to 0.
					 */
					__asm __volatile__(
						".set noreorder;"
						"li $29, (0x80000000);"
						"jr %0;"
						"li $31, (0)"
						:
						: "r" (bootaddr)
					);
				}
				for (cp = "\r\nulxp2> "; *cp != 0; cp++) {
					do {
						INW(c, IO_SIO);
					} while (c & SIO_TX_BUSY);
					OUTB(IO_SIO, *cp);
				}
			}
			loadaddr = NULL;
			cur_bits = 0;
			cur_word = 0;
			c = 0;
		}

		/* Normalize to capital letters */
		if (c >= 'a')
			c -= 32;

		if ((c >= '0' && c <= '9') || (c >= 'A'  && c <= 'F')) {
			if (c >= 'A')
				c = c - 'A' + 10;
			else
				c = c - '0';
			cur_word = (cur_word << 4) | (c & 0x0f);
			cur_bits = (cur_bits + 4) & 0x1f;
			if (cur_bits == 0) {
				if (loadaddr == NULL) {
					loadaddr = (int *) cur_word;
				} else {
					if (bootaddr == NULL)
						bootaddr = (void *) loadaddr;
					*loadaddr++ = cur_word;
				}
			}
			continue;
		}

		cur_bits = 0;
		if (c == 'X')
			goto defaultboot;
	} while (1);
}

