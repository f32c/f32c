/*-
 * Copyright (c) 2013 - 2015 Marko Zec, University of Zagreb
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

#include <dev/io.h>

extern __dead2 void binboot(void);


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


#ifdef ROM_LOADER
void
sio_boot(void)
#else
__dead2 void
_start(void)
#endif
{
	int c, cnt, pos, val, len;
	char *cp;
	void *base_addr = NULL;

	/* Appease gcc's uninitialized variable warnings */
	val = 0;

#ifndef ROM_LOADER
	/* Just in case CPU reset misses fetching the first instruction */
	__asm __volatile__("nop");
#endif

	cp = NULL;	/* shut up uninitialized use warnings */

prompt:
	pos = 0;
#ifdef __mips__
	c = 0x336d0A0D;			/* "\r\nm3" */
#else /* riscv */
	c = 0x76720A0D;			/* "\r\nrv" */
#endif
	do {
		pchar(c);
		c >>= 8;
		if (c == 0 && pos == 0) {
			pos = -1;
#ifdef __mips__
#ifdef __MIPSEB__
			c = 0x203E6232;	/* "2b> " */
#else
			c = 0x203E6c32;	/* "2l> " */
#endif
#else /* riscv */
			c = 0x203E3233;	/* "32> " */
#endif
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
#ifdef ROM_LOADER
			if (c == -1) /* Initiate binary load sequence? */
				return;
#endif
#ifdef BIN_LOADER
			if (c == -1) /* Initiate binary load sequence? */
				__asm __volatile__("j binboot");
#endif
			if (c == '\r') /* CR ? */
				goto prompt;
			/* Echo char */
			if (c >= 32)
				pchar(c);
		}
		val = 0;
		goto loop;
	}
	if (c >= 10 && c <= 13) /* CR / LF ? */
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
#ifdef __mips__
			__asm __volatile__(
			".set noreorder;"
			"lui $4, 0xF000;"	/* stack mask */
			"lui $5, 0x1000;"	/* top of the initial stack */
			"and $29, %0, $4;"	/* clr low bits of the stack */
 
			/* "beqz $29, cache_skip;" */ /* BRAM: no cache invalidate */
			"li $2, 0x8000;"	/* max. I-cache size: 32 K */
			"icache_flush:;"
			"cache 0, 0($2);"
			"bnez $2, icache_flush;"
			"addiu $2, $2, -4;"
			"cache_skip:;"

			"move $31, $0;"		/* ra <- zero */
			"jr %0;"
			"addu $29, $29, $5;"	/* set stack */
			".set reorder;"
			: 
			: "r" (base_addr)
			);
#else /* riscv */
			__asm __volatile__(
			"fence.i;"		/* flush I-cache */
			"lui s0, 0x80000;"	/* stack mask */
			"lui s1, 0x10000;"	/* top of the initial stack */
			"and sp, %0, s0;"	/* clr low bits of the stack */
			"or sp, sp, s1;"	/* set stack */
			"mv ra, zero;"	
			"jr %0;"
			: 
			: "r" (base_addr)
			);
#endif
		}
		if (val <= 3)
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

	/* Valid len? */
	if (len < 6)
		goto loop;

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
