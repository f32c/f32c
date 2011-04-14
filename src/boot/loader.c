
#include <types.h>
#include <io.h>
#include <sio.h>

typedef int mainfn_t(void);


int
main(void)
{
	mainfn_t *bootaddr;
	int *loadaddr;
	int cur_bits;
	int cur_word;
	int c;
	char *cp;
	
	goto start;

	do {
		do {
			INW(c, IO_SIO);
		} while ((c & SIO_RX_BYTES) == 0);
		c = (c >> 8) & 0xff;

		if ((void *) bootaddr == loadaddr)
			OUTB(IO_SIO, c);

		if (c == '\r') {
			if (loadaddr == NULL) {
				if (bootaddr != NULL) {
					/* Start with a clean stack */
					__asm __volatile__(" lui $29, 0x0001");
					bootaddr();
				}
start:
				bootaddr = NULL;
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
				if (loadaddr == NULL)
					loadaddr = (int *) cur_word;
				else {
					if (bootaddr == NULL)
						bootaddr = (void *) loadaddr;
					*loadaddr++ = cur_word;
				}
			}
		} else
			cur_bits = 0;
	} while (1);
}

