
#include <types.h>
#include <io.h>
#include <sio.h>


typedef int mainfn_t(void);

#define DEF_BOOTADDR	0x00000180

int coldboot = 1;	/* don't staticize or GCC will ignore this! */
static char *prompt = "\r\n\nf32c SoC bootloader\r\n> ";


void
_start(void)
{
	mainfn_t *bootaddr;
	int *loadaddr;
	int cur_bits;
	int cur_word;
	int c;
	char *cp;
	
	/* Set up IO base address */
	__asm __volatile__(
		"li $27, %0"
		:
		: "i" (IO_BASE)
	);

	if (coldboot) {
defaultboot:
		bootaddr = (void *) DEF_BOOTADDR;
	} else
		bootaddr = NULL;
	coldboot = 0;
	goto start;

	do {
		/* Blink LEDs while waiting for serial input */
		do {
			INW(c, IO_TSC);
			OUTB(IO_LED, c >> 20);
			INB(c, IO_SIO_STATUS);
		} while ((c & SIO_RX_FULL) == 0);
		INB(c, IO_SIO_BYTE);

		/* Echo character back to the serial port */
		if (bootaddr == NULL && loadaddr == NULL)
			OUTB(IO_SIO_BYTE, c);

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
				for (cp = prompt; *cp != 0; cp++) {
					do {
						INB(c, IO_SIO_STATUS);
					} while (c & SIO_TX_BUSY);
					OUTB(IO_SIO_BYTE, *cp);
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

