/*-
 * Copyright (c) 2013 - 2026 Marko Zec
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

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <dev/io.h>


static const char *bootfiles[] = {
	"/boot.bin",
	"/boot/cmd.bin",
	NULL
};


#define	RAM_BASE	0x80000000

#define LOAD_COOKIE	0x10adc0de


static char *
load_bin(const char *fname, int verbose)
{
	uint8_t hdrbuf[32];
	int fd;
	int i;
	char *cp;
	char *start, *bss, *end;
#ifdef __mips__
	int16_t *shortp = (void *) hdrbuf;
#else
	int32_t *longp = (void *) hdrbuf;
#endif

	if (verbose)
		printf("Trying %s... ", fname);
	fd = open(fname, O_RDONLY);
	if (fd < 0) {
		if (verbose)
			printf("not found\n");
		return (NULL);
	}

	i = read(fd, hdrbuf, sizeof(hdrbuf));
	close(fd);
	if (i != sizeof(hdrbuf)) {
		printf("short read\n");
		return (NULL);
	};

#ifdef __mips__
	if (hdrbuf[2] == 0x10 && hdrbuf[3] == 0x3c &&
	    hdrbuf[6] == 0x10 && hdrbuf[7] == 0x26 &&
	    hdrbuf[10] == 0x11 && hdrbuf[11] == 0x3c &&
	    hdrbuf[14] == 0x31 && hdrbuf[7] == 0x26) {
		/* Little-endian cookie found */
		start = (void *) ((shortp[0] << 16) + shortp[2]);
		end = (void *) ((shortp[4] << 16) + shortp[6]);
		bss = (void *) ((shortp[8] << 16) + shortp[10]);
#else /* !__mips__ */
	if (longp[0] == 0xf32c0037 &&
	    hdrbuf[4] == 0x37 && (hdrbuf[5] & 0xf) == 0x4 &&
	    hdrbuf[8] == 0x13 && hdrbuf[9] == 0x04 &&
	    hdrbuf[12] == 0x37 && (hdrbuf[13] & 0xf) == 0x4 &&
	    hdrbuf[16] == 0x13 && hdrbuf[17] == 0x04 &&
	    hdrbuf[20] == 0xb7 && (hdrbuf[21] & 0xf) == 0x4 &&
	    hdrbuf[24] == 0x93 && hdrbuf[25] == 0x84) {
		start = (void *) ((longp[1] & 0xfffff000) + (longp[2] >> 20));
		bss = (void *) ((longp[3] & 0xfffff000) + (longp[4] >> 20));
		end = (void *) ((longp[5] & 0xfffff000) + (longp[6] >> 20));
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
	} while (i > 0 && cp < bss);
	close(fd);
	
	if (cp != bss) {
		printf("corrupt text file, aborting\n");
		return (NULL);
	}

	if (verbose)
		printf("OK\nLoaded text & data at %p; bss at %p len %p\n\n",
		    start, bss, (void *) (end - bss));

	return (start);
}


void
main(void)
{
	int i;
	char *loadaddr = (void *) RAM_BASE;

	if (*((int *) loadaddr) == LOAD_COOKIE)
		loadaddr = load_bin(&loadaddr[4], 0);
	else {
		printf("f32c FAT bootloader v 0.5 "
#ifdef __mips__
#if _BYTE_ORDER == _BIG_ENDIAN
		    "(mips/be)"
#else
		    "(mips/le)"
#endif
#else /* !__mips__ */
		    "(riscv)"
#endif
		    " (built " __DATE__ ")\n");
		loadaddr = NULL;
	}

	for (i = 0; loadaddr == NULL && bootfiles[i] != NULL; i++)
		loadaddr = load_bin(bootfiles[i], 1);

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
