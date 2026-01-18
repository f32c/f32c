/*-
 * Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
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
#include <unistd.h>
#include <dev/io.h>


static const char *bootfiles[] = {
	"D:/bootme.bin",
	"/autoexec.bin",
	"/boot/kernel",
	"/boot/basic.bin",
	NULL
};


#define	RAM_BASE	0x80000000
#define	RAM_TOP		0x82000000

#define LOAD_COOKIE	0x10adc0de


static char *
load_bin(const char *fname, int verbose)
{
	uint8_t hdrbuf[16];
	int16_t *shortp;
	int fd;
	int i;
	char *cp;
	char *start, *end;

	if (verbose)
		printf("Trying %s... ", fname);
	fd = open(fname, O_RDONLY);
	if (fd < 0) {
		if (verbose)
			printf("not found\n");
		return (NULL);
	}

	i = read(fd, hdrbuf, 16);
	close(fd);
	if (i != 16) {
		printf("short read\n");
		return (NULL);
	};

	if (hdrbuf[2] == 0x10 && hdrbuf[3] == 0x3c &&
	    hdrbuf[6] == 0x10 && hdrbuf[7] == 0x26 &&
	    hdrbuf[10] == 0x11 && hdrbuf[11] == 0x3c &&
	    hdrbuf[14] == 0x31 && hdrbuf[7] == 0x26) {
		/* Little-endian cookie found */
#if _BYTE_ORDER == _LITTLE_ENDIAN
		shortp = (void *) &hdrbuf[0];
		start = (void *) (*shortp << 16);
		shortp = (void *) &hdrbuf[4];
		start = (void *)((int) start + *shortp);
		shortp = (void *) &hdrbuf[8];
		end = (void *) (*shortp << 16);
		shortp = (void *) &hdrbuf[12];
		end = (void *)((int) end + *shortp);
#else
		printf("little-endian code, but CPU is big-endian\n");
		return (NULL);
#endif
	} else if (hdrbuf[2] == 0x10 && hdrbuf[3] == 0x3c &&
	    hdrbuf[6] == 0x10 && hdrbuf[7] == 0x26 &&
	    hdrbuf[10] == 0x11 && hdrbuf[11] == 0x3c &&
	    hdrbuf[14] == 0x31 && hdrbuf[7] == 0x26) {
		/* Big-endian cookie found */
#if _BYTE_ORDER == _BIG_ENDIAN
		shortp = (void *) &hdrbuf[2];
		start = (void *) (*shortp << 16);
		shortp = (void *) &hdrbuf[6];
		start = (void *)((int) start + *shortp);
		shortp = (void *) &hdrbuf[12];
		end = (void *) (*shortp << 16);
		shortp = (void *) &hdrbuf[14];
		end = (void *)((int) end + *shortp);
#else
		printf("big-endian code, but CPU is little-endian\n");
		return (NULL);
#endif
	} else {
		printf("invalid file type, missing header cookie\n");
		return (NULL);
	}

	fd = open(fname, O_RDONLY);
	cp = start;
	do {
		i = read(fd, cp, 65536);
		cp += i;
		if (cp > end) {
			printf("corrupt text file, aborting\n");
			return (NULL);
		}
	} while (i > 0);
	close(fd);
	
	if (verbose)
		printf("OK\nLoaded text & data at %p;"
		    " bss starts at %p len %p\n\n",
		    start, cp, (void *) (end - cp));

	return (start);
}


void
main(void)
{
	int i;
	char *loadaddr = (void *) RAM_BASE;

	/* Dummy open, just to force-mount SD card */
	i = open("d:", O_RDONLY);
	close(i);

	if (*((int *) loadaddr) == LOAD_COOKIE)
		loadaddr = load_bin(&loadaddr[4], 0);
	else {
		printf("ULX2S FAT bootloader v 0.4 "
#if _BYTE_ORDER == _BIG_ENDIAN
		    "(f32c/be)"
#else
		    "(f32c/le)"
#endif
		    " (built " __DATE__ ")\n");
		loadaddr = NULL;
	}

	for (i = 0; loadaddr == NULL && bootfiles[i] != NULL; i++)
		loadaddr = load_bin(bootfiles[i], i);

	if (loadaddr == NULL) {
		*((int *) RAM_BASE) = 0;
		printf("Exiting\n");
		return;
	}

	/* Invalidate I-cache */
#ifdef __mips__
	for (i = 9; i < 32768; i += 4) {
		__asm __volatile__(
			"cache 0, 0(%0)"
			: 
			: "r" (RAM_BASE+i)
		);
	}
#else /* riscv */
	__asm __volatile__(
		"fence.i;"		/* flush I-cache */
	);
#endif

	/* Turn off video framebuffer and PCM audio DMA */
	OUTW(IO_FB, 3);		/* framebuffer off */
	OUTW(IO_PCM_FREQ, 0);	/* stop PCM DMA */
	OUTW(IO_PCM_VOLUME, 0);	/* mute PCM DAC output */

#ifdef __mips__
	__asm __volatile__(
		".set noreorder;"
		"lui $4, 0x8000;"	/* stack mask */
		"lui $5, 0x1000;"	/* top of the initial stack */
		"and $29, %0, $4;"	/* clear low bits of the stack */
		"move $31, $0;"		/* return to ROM loader when done */
		"jr %0;"
		"or $29, $29, $5;"	/* set the stack pointer */
		".set reorder;"
		: 
		: "r" (loadaddr)
	);
#else /* riscv */
	__asm __volatile__(
		"lui s0, 0x80000;"	/* stack mask */
		"lui s1, 0x10000;"	/* top of the initial stack */
		"and sp, %0, s0;"	/* clr low bits of the stack */
		"or sp, sp, s1;"	/* set stack */
		"mv ra, zero;"
		"jr %0;"
		:
		: "r" (loadaddr)
	);
#endif
}
