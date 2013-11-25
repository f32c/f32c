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

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>


static const char *bootfiles[] = {
	"1:/bootme.bin",
	"/boot/kernel",
	"/boot/basic.bin",
	NULL
};


#define	SRAM_BASE	0x80000000
#define	SRAM_TOP	0x80100000
#define	LOADER_BASE	0x800f8000

#define LOAD_COOKIE	0x10adc0de
#define	LOADADDR	SRAM_BASE


void
main(void)
{
	int i, fd = -1;
	char *cp = (char *) LOADADDR;

	printf("ULX2S FAT bootloader v 0.1 "
#if _BYTE_ORDER == _BIG_ENDIAN
	    "(f32c/be)"
#else
	    "(f32c/le)"
#endif
	    "\n");

	if (*((int *) cp) == LOAD_COOKIE) {
		printf("Trying %s... ", &cp[4]);
		fd = open(&cp[4], O_RDONLY);
		if (fd < 0)
			printf("not found\n");
	}

	for (i = 0; fd < 0 && bootfiles[i] != NULL; i++) {
		printf("Trying %s... ", bootfiles[i]);
		fd = open(bootfiles[i], O_RDONLY);
		if (fd > 0)
			break;
		printf("not found\n");
	}
	if (fd < 0) {
		printf("Exiting\n");
		return;
	}

	do {
		i = read(fd, cp, 65536);
		cp += i;
	} while (i > 0);
	printf("OK, loaded at %p len %p\n\n",
	    (void *) LOADADDR, (cp - LOADADDR));

	/* bzero() the rest of the available SRAM */
	do {
		*cp++ = 0;
	} while (((int) cp & 3));
	do {
		*((int *) cp) = 0;
		cp += 4;
	} while (cp < (char *) LOADER_BASE);

	/* Invalidate I-cache */
	cp = (char *) LOADADDR;
	for (i = 0; i < 8192; i += 4, cp += 4) {
		__asm __volatile__(
			"cache	0, 0(%0)"
			: 
			: "r" (cp)
		);
	}

	cp = (char *) LOADADDR;
	__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"	/* stack mask */
		"lui $5, 0x0010;"	/* top of the initial stack */
                "and $29, %0, $4;"	/* clear low bits of the stack */
                "move $31, $0;"		/* return to ROM loader when done */
		"jr %0;"
		"or $29, $29, $5;"      /* set the stack pointer */
		".set reorder;"
		: 
		: "r" (cp)
	);
}
