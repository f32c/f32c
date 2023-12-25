/*-
 * Copyright (c) 2013, 2016 Marko Zec
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

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <fatfs/ff.h>

#include <dev/io.h>
#include <dev/spi.h>

#include "bas.h"


#define	RAM_BASE	0x80000000
#define	LOADER_BASE	0x800F0000

#define	LOAD_COOKIE	0x10adc0de
#define	LOADADDR	RAM_BASE

#define FLASH_FAT_OFFSET 0x100000
#define LOADER_START     0x100200

/*
 * If compiling with EMBEDDED_LOADER first prepare loader_bin.h using:
 * hexdump -v -e '1/1 "%u,\n"' ../../boot/fat/loader.bin > loader_bin.h
 * and set LOADER_LEN to the exact length of the loader.bin file.
 */
//#define EMBEDDED_LOADER
#ifdef EMBEDDED_LOADER
#define LOADER_LEN 9716
static char loader_bin[LOADER_LEN] = {
#include "loader_bin.h"
};
#endif


#ifndef EMBEDDED_LOADER
static void
flash_read_block(char *buf, uint32_t addr, uint32_t len)
{

	spi_start_transaction(IO_SPI_FLASH);
	spi_byte(IO_SPI_FLASH, 0x0b); /* High-speed read */
	spi_byte(IO_SPI_FLASH, addr >> 16);
	spi_byte(IO_SPI_FLASH, addr >> 8);
	spi_byte(IO_SPI_FLASH, addr);
	spi_byte(IO_SPI_FLASH, 0xff); /* dummy byte, ignored */
	spi_block_in(IO_SPI_FLASH, buf, len);
}
#endif


int
bauds(void)
{
	int bauds;

	bauds = evalint();
	check();
	if (sio_setbaud(bauds))
		error(33);	/* argument error */
	normret;
}


int
bas_sleep(void)
{
	int c = 0;
	int t, target;

	RDTSC(target);

	evalreal();
	check();
	if (res.f < ZERO)
		error(33);	/* argument error */

	target += (int) (res.f * 1000.0 * freq_khz);

	do {
		__asm("di");
		RDTSC(t);
		if (t < tsc_lo)
			tsc_hi++;
		tsc_lo = t;
		__asm("ei");

		if(t - target > 0)
			break;

		c = sio_getchar(0);
#ifdef __mips__
//		asm("wait"); /* Low-power mode */
#endif
	} while (c != 3);

	if (c == 3)
		trapped = 1;
	normret;
}


int
bas_exec(void)
{
	char buf[256];
	STR st;
	uint32_t *up = (void *) RAM_BASE;
	uint8_t *cp = (void *) LOADER_BASE;
	int len;
	uint32_t i;
#ifndef EMBEDDED_LOADER
	int res_sec, sec_size;
#endif

	st = stringeval();
	NULL_TERMINATE(st);
	strcpy(buf, st->strval);
	len = strlen(buf);
	if (len >= 1 && buf[1] != ':') {
		if (buf[0] == '/') {
			f_getcwd(buf, sizeof(buf));
			strcpy(&buf[2], st->strval);
		} else {
			f_getcwd(buf, sizeof(buf));
			len = strlen(buf);
			buf[len++] = '/';
			strcpy(&buf[len], st->strval);
		}
	}
	FREE_STR(st);
	check();

	if (open(buf, O_RDONLY) < 0)
		sprintf(&buf[strlen(buf)], ".bin");
	if (open(buf, O_RDONLY) < 0)
		error(15);

	*up = LOAD_COOKIE;
	strcpy((void *) &up[1], buf);

	/* Clear loaders' BSS, just in case... */
	bzero(cp, 32768);

#ifdef EMBEDDED_LOADER
	memcpy(cp, loader_bin, LOADER_LEN);
#else /* !EMBEDDED_LOADER */
	flash_read_block((void *) cp, FLASH_FAT_OFFSET, 512);
	sec_size = (cp[0xc] << 8) + cp[0xb];
	res_sec = (cp[0xf] << 8) + cp[0xe];
	if (cp[0x1fe] != 0x55 || cp[0x1ff] != 0xaa || sec_size != 4096
	    || res_sec < 2) {
		printf("Invalid boot sector\n");
		error(15);
	}

	len = sec_size * res_sec - (LOADER_START - FLASH_FAT_OFFSET);
	flash_read_block((void *) cp, FLASH_FAT_OFFSET, len);
#endif

#ifdef __mips__
	/* Invalidate I-cache */
	for (i = 0; i < 32768; i += 4) {
		__asm __volatile__(
			"cache 0, 0(%0)"
			: 
			: "r" (i + (uint32_t)cp)
		);
	}

	__asm __volatile__(
		".set noreorder;"
		"di;"			/* Disable all interrupts */
		"mtc0 $0, $12;"		/* Mask all interrupts */
		"lui $4, 0x8000;"       /* stack mask */
		"lui $5, 0x1000;"       /* top of the initial stack */
		"and $29, %0, $4;"      /* clear low bits of the stack */
		"move $31, $0;"         /* return to ROM loader when done */
		"jr %0;"
		"or $29, $29, $5;"      /* set the stack pointer */
		".set reorder;"
		:
		: "r" (0)
	);
#else /* riscv */
	/* XXX fixme! */
#endif

	/* Actually, not reached */
	normret;
}
