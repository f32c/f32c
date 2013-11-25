/*-
 * Copyright (c) 2013 Marko Zec
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id$
 */

#include <io.h>


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
#ifdef ROM_LOADER
sio_boot(void)
#else
_start(void)
#endif
{
	int c, cnt, pos, val, len;
	char *cp;
	void *base_addr = NULL;

	__asm __volatile__(
		"move $31, $0;"
	);

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
	pos = 0;
	c = 0x33660A0D;			/* "\r\nf3" */
	do {
		pchar(c);
		c >>= 8;
		if (c == 0 && pos == 0) {
			pos = -1;
			c = 0x203E6332;	/* "2c> " */
		}
	} while (c != 0);

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
			if (c >= 32)
				pchar(c);
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
			__asm __volatile__(
			".set noreorder;"
			"lui $4, 0x8000;"	/* stack mask */
			"lui $5, 0x0010;"	/* top of the initial stack */
			"and $29, %0, $4;"	/* clr low bits of the stack */
			"jr %0;"
			"or $29, $29, $5;"	/* set stack */
			".set reorder;"
			: 
			: "r" (base_addr)
			);
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
