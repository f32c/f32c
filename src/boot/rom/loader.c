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

#include <spi.h>
#include <sio.h>
#include <stdio.h>


#define	SRAM_BASE	0x80000000
#define	SRAM_TOP	0x80100000
#define	LOADER_BASE	0x800f8000

#ifndef ONLY_I_ROM
#if _BYTE_ORDER == _BIG_ENDIAN
static const char *msg = "ULX2S ROM bootloader v 0.1 (f32c/be)\n";
#else
static const char *msg = "ULX2S ROM bootloader v 0.1 (f32c/le)\n";
#endif
#endif /* !ONLY_I_ROM */


void sio_boot(void);


static void
flash_read_block(char *buf, uint32_t addr, uint32_t len)
{

	spi_start_transaction(SPI_PORT_FLASH);
	spi_byte(SPI_PORT_FLASH, 0x0b); /* High-speed read */
	spi_byte(SPI_PORT_FLASH, addr >> 16);
	spi_byte(SPI_PORT_FLASH, addr >> 8);
	spi_byte(SPI_PORT_FLASH, addr);
	spi_byte(SPI_PORT_FLASH, 0xff); /* dummy byte, ignored */
	spi_block_in(SPI_PORT_FLASH, buf, len);
}


static void
pchar(char c)
{
	int s;

	do {
		INB(s, IO_SIO_STATUS);
	} while (s & SIO_TX_BUSY);
	OUTB(IO_SIO_BYTE, (c));
}


#ifndef ONLY_I_ROM
static void
phex(uint8_t c)
{
	int hc = (((c) >> 4) & 0xf) + '0';

	if (hc > '9')
		hc += 'a' - '9' - 1;
	pchar(hc);
	hc = ((c) & 0xf) + '0';
	if (hc > '9')
		hc += 'a' - '9' - 1;
	pchar(hc);
}


static void
phex32(uint32_t c)
{

	phex(c >> 24);
	phex(c >> 16);
	phex(c >> 8);
	phex(c);
}


static void
puts(const char *cp)
{

	for (; *cp != 0; cp++) {
		if (*cp == '\n')
			pchar('\r');
		pchar(*cp);
	}
}
#else /* ONLY_I_ROM */
#define	puts(c)
#define	phex32(c)
#endif /* !ONLY_I_ROM */


static uint8_t
sio_getch()
{
	uint8_t c;

	do {
		INB(c, IO_SIO_STATUS);
	} while ((c & SIO_RX_FULL) == 0);
	INB(c, IO_SIO_BYTE);
	return (c & 0xff);
}


static void *
sio_load_binary(void)
{
	uint32_t i, t;
	uint32_t csum, base, len;
	char *cp;

	do {
		OUTB(IO_LED, (base) >> 10);
		i = sio_getch();
		switch (i) {
		case 0x80:	/* Set base addr */
			for (i = 0; i < 4; i++)
				base = (base << 8) + sio_getch();
			break;
		case 0x81:	/* Read csum */
			t = csum;
			for (i = 0; i < 4; i++) {
				pchar(t >> 24);
				t <<= 8;
			}
			break;
		case 0x90:	/* Set len = base */
			len = base;
			break;
		case 0x91:	/* Set csum = base */
			csum = base;
			break;
		case 0xa0:	/* Write block */
			cp = (void *) base;
			csum = 0;
			for (i = 0; i < len; i++) {
				t = sio_getch();
				cp[i] = t;
				csum += t;
			}
			break;
		case 0xa1:	/* Read block */
			cp = (void *) base;
			csum = 0;
			for (i = 0; i < len; i++) {
				t = cp[i];
				pchar(t);
				csum += t;
			}
			break;
		case 0xb0:	/* Set baudrate, abuse base as speed */
			sio_setbaud(base);
			break;
		case 0xb1:	/* Done, jump to base */
			return ((void *) base);
			break;
		default:
			break;
		}
	} while (1);
}


void
main(void)
{
	uint8_t *cp = (void *) LOADER_BASE;
	int *p;
	int res_sec, sec_size, len, i;

	/* Turn on LEDs */
	OUTB(IO_LED, 255);

	/* Turn off video framebuffer, just in case */
	OUTW(IO_FB, 3);

	/* Reset all CPU cores except CPU #0 */
	OUTW(IO_CPU_RESET, ~1);

	/* Crude SRAM self-test & bzero() */
	for (i = -1; i <= 0; i++) {
		/* memset() SRAM */
		for (p = (int *) SRAM_BASE; p < (int *) SRAM_TOP; p++)
			*p = i;

		/* check SRAM */
		for (p = (int *) SRAM_BASE; p < (int *) SRAM_TOP; p += 4)
			if (p[0] + p[1] + p[3] + p[4] != i << 2) {
				puts("SRAM BIST failed\n");
				/* Blink LEDs: on/off 1:1 */
				do {
					if ((i++ >> 22) & 1)
						OUTB(IO_LED, 255);
					else
						OUTB(IO_LED, 0);
				} while (1);
			}
	}

	puts("SRAM BIST passed\n");
	puts(msg);

	flash_read_block((void *) cp, 0, 512);
	sec_size = (cp[0xc] << 8) + cp[0xb];
	res_sec = (cp[0xf] << 8) + cp[0xe];
	if (cp[0x1fe] != 0x55 || cp[0x1ff] != 0xaa || sec_size != 4096
	    || res_sec < 2) {
		puts("Invalid boot sector\n");
		sio_boot();
		cp = sio_load_binary();
		goto boot;
	}

	len = sec_size * res_sec - 512;
	flash_read_block((void *) cp, 512, len);
	puts("Boot block loaded from SPI flash at 0x");
	phex32((uint32_t) cp);
	puts(" len 0x");
	phex32(len);
	puts("\n\n");

	/* Turn off LEDs before jumping to next loader stage */
#if 0
	OUTB(IO_LED, 0);
#else
	asm("sb $0, -239($0);");
#endif

	/* Check SIO RX buffer */
	INB(i, IO_SIO_STATUS);
	if (i & SIO_RX_FULL) {
		INB(i, IO_SIO_BYTE);
		if (i == ' ') {
			sio_boot();
			cp = sio_load_binary();
		}
	}
	
boot:
	__asm __volatile__(
		".set noreorder;"
		".set noat;"
		"move $1, %0;"
		"lui $4, 0x8000;"	/* stack mask */
		"lui $5, 0x0010;"	/* top of the initial stack */
		"and $29, %0, $4;"	/* clear low bits of the stack */

		"beqz $29, cache_skip;"	/* skip cache invalidate for BRAM */
		"li $2, 0x4000;"	/* max. I-cache size: 16 K */
		"icache_flush:;"
		"addiu $2, $2, -4;"
		"cache 0, 0($4);"
		"bnez $2, icache_flush;"
		"addiu $4, $4, 4;"
		"cache_skip:;"

		"move $31, $0;"		/* return to ROM loader when done */
		"jr $1;"
		"or $29, $29, $5;"	/* set the stack pointer */
		".set at;"
		".set reorder;"
		:
		: "r" (cp)
	);
}
