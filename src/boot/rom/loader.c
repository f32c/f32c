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
 * $Id: $
 */

#include <sys/param.h>

#include <spi.h>
#include <stdio.h>


#define	SRAM_BASE	0x80000000
#define	SRAM_TOP	0x80100000
#define	LOADER_BASE	0x800f8000

#define	ONLY_I_ROM

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


#ifndef ONLY_I_ROM
static void
pchar(char c)
{
	int s;

	do {
		INB(s, IO_SIO_STATUS);
	} while (s & SIO_TX_BUSY);
	OUTB(IO_SIO_BYTE, (c));
}


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
#define	pchar(c)
#define	phex32(c)
#endif /* !ONLY_I_ROM */


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
		for (p = (int *) SRAM_BASE; p < (int *) SRAM_TOP; p++)
			if (*p != i) {
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
#if 0
		/* Blink LEDs: on/off 1:3 */
		do {
			if (((i++ >> 22) & 3) == 0)
				OUTB(IO_LED, 255);
			else
				OUTB(IO_LED, 0);
		} while (1);
#else
		sio_boot();
#endif
	}

	len = sec_size * res_sec - 512;
	flash_read_block((void *) cp, 512, len);
	puts("Boot block loaded from SPI flash at 0x");
	phex32((uint32_t) cp);
	puts(" len 0x");
	phex32(len);
	puts("\n\n");

	/* Turn off LEDs before jumping to next loader stage */
	OUTB(IO_LED, 0);

	/* Check for keypress */
	INB(i, IO_SIO_STATUS);
	if (i & SIO_RX_FULL) {
		INB(i, IO_SIO_BYTE);
		if (i == ' ')
			sio_boot();
	}
	

	__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"       /* stack mask */
		"lui $5, 0x0010;"       /* top of the initial stack */
		"and $29, %0, $4;"      /* clear low bits of the stack */
		"move $31, $0;"         /* return to ROM loader when done */
		"jr %0;"
		"or $29, $29, $5;"      /* set the stack pointer */
		".set reorder;"
		:
		: "r" (cp)
	);
}
