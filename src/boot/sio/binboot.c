/*-
 * Copyright (c) 2015-2026 Marko Zec
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
 */

#include <dev/io.h>
#include <dev/sio.h>
#include <stdio.h>

#define	IO_SIO_DATA	(IO_SIO_0 + 0x0)
#define	IO_SIO_STATUS	(IO_SIO_0 + 0x4)


static inline void
__attribute__((always_inline))
pchar(char c)
{
	int s;

	do {
		INB(s, IO_SIO_STATUS);
	} while (s & SIO_TX_BUSY);
	OUTB(IO_SIO_DATA, (c));
}


static inline uint8_t
__attribute__((always_inline))
sio_getch_blink()
{
	uint32_t c;

	do {
		RDTSC(c);
		OUTB(IO_LED, (c >> 24));
		INB(c, IO_SIO_STATUS);
	} while ((c & SIO_RX_FULL) == 0);
	INB(c, IO_SIO_DATA);
	return (c & 0xff);
}


static inline uint8_t
__attribute__((always_inline))
sio_getch()
{
	uint32_t c;

	do {
		INB(c, IO_SIO_STATUS);
	} while ((c & SIO_RX_FULL) == 0);
	INB(c, IO_SIO_DATA);
	return (c & 0xff);
}


__dead2 void
binboot(void)
{
	uint32_t i, t;
	uint32_t crc = 0, base = 0, len = 0;
	char *cp;

	do {
		i = sio_getch_blink();
		switch (i) {
		case 0x80:	/* Set base addr */
			for (i = 0; i < 4; i++)
				base = (base << 8) + sio_getch();
			break;
		case 0x81:	/* Read crc */
			t = crc;
			for (i = 0; i < 4; i++) {
				pchar(t >> 24);
				t <<= 8;
			}
			break;
		case 0x90:	/* Set len = base */
			len = base;
			break;
		case 0x91:	/* Set crc = base */
			crc = base;
			break;
		case 0xa0:	/* Write block */
			cp = (void *) base;
			crc = 0;
			for (i = 0; i < len; i++) {
				crc = (crc >> 31) | (crc << 1);
				t = sio_getch();
				cp[i] = t;
				crc += t;
			}
			break;
		case 0xb1:	/* Done, jump to base */
#ifdef __mips__
			__asm __volatile__(
			".set noreorder;"
			"lui $4, 0xF000;"	/* stack mask */
			"lui $5, 0x1000;"	/* top of the initial stack */
			"and $29, %0, $4;"	/* clr low bits of the stack */

			/* "beqz $29, cache_skip;" */	/* skip cache invalidate for BRAM */
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
			: "r" (base)
			);
#else /* riscv */
			__asm __volatile__(
			"lui s0, 0x8000;"	/* stack mask */
			"lui s1, 0x1000;"	/* top of the initial stack */
			"and sp, %0, s0;"	/* clr low bits of the stack */
			"or sp, sp, s1;"	/* set stack */
			"mv ra, zero;"		/* ra <- zero */
			"jr %0;"
			:
			: "r" (base)
			);
#endif
		default:
			/* Detected 7-bit ASCII, return to hex loader */
#ifdef __mips__
			__asm __volatile__("jr $0");
#else /* riscv */
			__asm __volatile__("jr zero");
#endif
		}
	} while (1);
}
