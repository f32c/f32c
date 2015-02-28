/*-
 * Copyright (c) 2013 Marko Zec, University of Zagreb
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
#include <spi.h>


#if (_BYTE_ORDER == _LITTLE_ENDIAN)
#define	SPI_READY_MASK (1 << 8)
#else
#define	SPI_READY_MASK (1 << 16)
#endif

void
spi_block_in(int port, void *buf, int len)
{
	uint32_t *wp = (uint32_t *) buf;
	uint32_t w = 0;
	uint32_t c;

	if (len == 0)
		return;

	SB(0xff, IO_SPI_FLASH, port);
	do {
		LW(c, IO_SPI_FLASH, port);
	} while ((c & SPI_READY_MASK) == 0);
	for (len--; len != 0; len--) {
		SB(0xff, IO_SPI_FLASH, port);
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
		w = (w >> 8) | (c << 24);
#else
		w = (w << 8) | (c >> 24);
#endif
		if ((len & 3) == 0)
			*wp++ = w;
		do {
			LW(c, IO_SPI_FLASH, port);
		} while ((c & SPI_READY_MASK) == 0);
	}
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
	w = (w >> 8) | (c << 24);
#else
	w = (w << 8) | (c >> 24);
#endif
	*wp++ = w;
}


int
spi_byte(int port, int out)
{
	uint32_t in;

	SB(out, IO_SPI_FLASH, port);
	do {
		LW(in, IO_SPI_FLASH, port);
	} while ((in & SPI_READY_MASK) == 0);
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
	return (in & 0xff);
#else
	return (in >> 24);
#endif
}


void
spi_start_transaction(int port)
{
	uint32_t in;

	SB(0x80, IO_SPI_FLASH, port + 1);
	do {
		LW(in, IO_SPI_FLASH, port + 1);
	} while ((in & SPI_READY_MASK) == 0);
}
