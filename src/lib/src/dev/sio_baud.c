/*-
 * Copyright (c) 2013, 2023 Marko Zec
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


static uint16_t sio_bauds[16] = {
	3,	6,	12,	24,	48,	96,	192,	384,
	576,	1152,	2304,	4608,	9216,	10000,	15000,	30000
};

/*
 * Set RS-232 baudrate.
 */
int
sio_setbaud(int bauds)
{
	int i;

	for (i = 0, bauds /= 100; i < 16; i++)
		if (sio_bauds[i] == bauds) {
			OUTB(IO_SIO_BAUD, i);
			return (0);
		}
	return (-1);
}

/*
 * Get RS-232 baudrate.
 */
int
sio_getbaud(void)
{
	int i;

	INB(i, IO_SIO_BAUD);
	return (sio_bauds[i] * 100);
}
