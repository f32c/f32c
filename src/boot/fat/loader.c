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

#include <ctype.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <sys/elf.h>
#include <sys/exec.h>
#include <sys/mount.h>

#include <fatfs/diskio.h>

#include <dev/io.h>

extern char **environ;
extern void *__memtop;
extern void *__ramdisk;
extern void *_start;

static const char *bootfiles[] = {
	"/boot.bin",
	"/boot/cmd.bin",
	NULL
};


static char *
load_bin(const char *fname, int verbose)
{
	uint8_t hdrbuf[40];
	int fd;
	int i;
	char *cp;
	uint32_t entry, tsiz, dsiz;
	char *start, *bss, *end;
	int32_t *longp = (void *) hdrbuf;
#ifdef __mips__
	int16_t *shortp = (void *) hdrbuf;
#endif

	if (verbose)
		printf("Trying %s... ", fname);
	fd = open(fname, O_RDONLY);
	if (fd < 0) {
		if (verbose)
			printf("not found\n");
		return (NULL);
	}

	if (elfinfo(fd, &entry, &tsiz, &dsiz) == 0) {
		start = (void *) entry;
		if (verbose)
			printf("ELF text @ %p,0x%x data @ %p,0x%x",
			    start, tsiz, &start[tsiz], dsiz);
		if (elfload(fd, start, tsiz, &start[tsiz], dsiz) == 0) {
			if (verbose)
				printf(" OK\n");
			close(fd);
			return (start);
		}
		close(fd);
		printf(" invalid ELF file\n");
		return (NULL);
	}

	lseek(fd, 0, SEEK_SET);
	i = read(fd, hdrbuf, sizeof(hdrbuf));
	close(fd);
	if (i != sizeof(hdrbuf)) {
		printf("short read\n");
		return (NULL);
	};

#ifdef __mips__
	if (longp[0] == 0x3c00f32c &&
	    shortp[3] == 0x3c10 && shortp[5] == 0x2610 &&
	    shortp[7] == 0x3c1b && shortp[9] == 0x277b &&
	    shortp[11] == 0x3c10 && shortp[13] == 0x2610 &&
	    shortp[15] == 0x3c11 && shortp[17] == 0x2631) {
		/* Little-endian cookie found */
		start = (void *) ((shortp[2] << 16) + shortp[4]);
		bss = (void *) ((shortp[10] << 16) + shortp[12]);
		end = (void *) ((shortp[14] << 16) + shortp[16]);
#else /* !__mips__ */
	if (longp[0] == 0xf32c0037 &&
	    hdrbuf[4] == 0x37 && (hdrbuf[5] & 0xf) == 0x4 &&
	    hdrbuf[8] == 0x13 && hdrbuf[9] == 0x04 &&
	    hdrbuf[12] == 0x37 && (hdrbuf[13] & 0xf) == 0x2 &&
	    hdrbuf[16] == 0x13 && hdrbuf[17] == 0x02 &&
	    hdrbuf[20] == 0x37 && (hdrbuf[21] & 0xf) == 0x4 &&
	    hdrbuf[24] == 0x13 && hdrbuf[25] == 0x04 &&
	    hdrbuf[28] == 0xb7 && (hdrbuf[29] & 0xf) == 0x4 &&
	    hdrbuf[32] == 0x93 && hdrbuf[33] == 0x84) {
		start = (void *) ((longp[1] & 0xfffff000) + (longp[2] >> 20));
		bss = (void *) ((longp[5] & 0xfffff000) + (longp[6] >> 20));
		end = (void *) ((longp[7] & 0xfffff000) + (longp[8] >> 20));
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
	
	if (bss < cp || bss > cp + 4) {
		printf("corrupt text file, aborting\n");
		return (NULL);
	}

	if (verbose)
		printf("OK\nLoaded text & data at %p; bss at %p len %p\n",
		    start, bss, (void *) (end - bss));

	return (start);
}


static void
loadenv(const char *path)
{
	FILE *fp;
	int len;
	char *line = NULL;
	size_t linecap;

	fp = fopen(path, "r");
	clearenv();
	while (fp != NULL) {
		len = getline(&line, &linecap, fp);
		if (len < 0) {
			free(line);
			fclose(fp);
			return;
		}
		line[len] = 0;

		/* Skip comments and blank lines */
		if (!isalpha(line[0]))
			continue;

		if (putenv(line) == 0)
			line = NULL; /* consumed by putenv() */
		else
			printf("putenv(%s) failed\n", line);
	}
}


static uint32_t
strtomemsiz(const char *cp)
{
	uint32_t val = strtoul(cp, NULL, 0);

	/* Search for unit specifier (K or M) */
	if (cp[0] == '0' && (cp[1] == 'x' || cp[1] == 'X'))
		cp += 2;
	for (; isxdigit(*cp); cp++) {}
	if (*cp == 'k' || *cp == 'K')
		val <<= 10;
	else if (*cp == 'm' || *cp == 'M')
		val <<= 20;
	return (val);
}


void
main(void)
{
	struct f32c_execinfo *f32c_eip = (void *) F32C_EXECINFO_ADDR;
	void *loadaddr = NULL;
	void *sp = (void *) 0x84000000;
	char **argv = NULL;
	char **envp = NULL;
	char *cp;
	int argc = 0;
	int i, c, loader_area, size, envc;
	struct timespec tv0, tv1;
	char execpath[128];
	uint32_t ramsiz = 0, ramdisksiz = 0;
	uint32_t bytespersec, totsec;

	/* If f32c trampoline requested, load the binary, set the env, boot */
	if (f32c_eip->cookie == F32C_EXECINFO_COOKIE && f32c_eip->tries == 1
	    && (argc = f32c_eip->argc) > 0 && f32c_eip->argv != NULL
	    && f32c_eip->envp == &f32c_eip->argv[argc]) {
		/* XXX todo: check f32c_eip->csum */
		f32c_eip->cookie = 0xdeadc0de;

		/* Allocate space for argv / envp / strings at local stack */
		sp = argv = alloca(f32c_eip->size);
		environ = envp = &argv[argc];

		/* Safely move argv / envp / strings to the local stack */
		memmove(argv, f32c_eip->argv, f32c_eip->size);

		/* Propagate memtop, ramdisk */
		__memtop = f32c_eip->memtop;
		__ramdisk = f32c_eip->ramdisk;

		/* Adjust argv / envp pointer addresses */
		for (i = 0; argv[i] != NULL; i++)
			argv[i] += (argv - f32c_eip->argv) * sizeof(char *);

		loadaddr = load_bin(argv[0], 0);
		if (loadaddr != NULL)
			goto boot;
		printf("%s: load failed\n", argv[0]);
		return;
	}

	/* Parse and set the boot environment */
	loadenv("/boot/loader.conf");

	/* Adjust console baud rate */
	if ((cp = getenv("bauds")) != NULL && (i = strtoul(cp, NULL, 0)) > 0)
		sio_setbaud(i);

	/* Fetch ramsiz */
	if ((cp = getenv("ramsize")) != NULL)
		ramsiz = strtomemsiz(cp);

	/* Fetch ramdisksiz */
	if ((cp = getenv("ramdisksize")) != NULL)
		ramdisksiz = strtomemsiz(cp);

	/* Print out identification message */
	printf("f32c "
#ifdef __mips__
#if _BYTE_ORDER == _BIG_ENDIAN
	    "(mips/be)"
#else
	    "(mips/le)"
#endif
#else /* !__mips__ */
	    "(riscv)"
#endif
	    " FAT bootloader v 0.7 (" __DATE__ ")\n");

	do {
		if (ramsiz == 0)
			break;
		if ((ramsiz & 0x3ff) != 0) {
			printf("RAM size of 0x%x not aligned to 1024 B, "
			    "ignoring\n", ramsiz);
			break;
		}
		loader_area = (uint32_t) sp - (uint32_t) &_start;
		ramsiz -= loader_area;
		__memtop = (void *) 0x80000000 + ramsiz;

		if (ramdisksiz == 0)
			break;
		if ((ramdisksiz & 0x3ff) != 0) {
			printf("RAM disk size of 0x%x not aligned to 1024 B, "
			    "ignoring\n", ramdisksiz);
			break;
		}
		if (ramdisksiz >= ramsiz) {
			printf("RAM disk size of 0x%x exceeds available"
			    "memory size of 0x%08x, ignoring\n",
			    ramdisksiz, ramsiz);
			break;
		}

		__memtop -= ramdisksiz;
		ramsiz -= ramdisksiz;
		__ramdisk = __memtop;
		printf("RAM disk: %d Kbytes at %p", ramdisksiz / 1024,
		    __ramdisk);

		cp = __ramdisk;
		bytespersec = cp[11] + cp[12] * 256;
		totsec = cp[19] + cp[20] * 256;

		if (!is_fat_volume(__ramdisk) ||
		    bytespersec * totsec != ramdisksiz) {
			printf(", uninitialized, formatting...\n");
			mkfs("R:", 0, ramdisksiz);
		} else
			printf("\n");
	} while (0);

	if (ramsiz != 0)
		printf("Available RAM: %d Kbytes\n", ramsiz / 1024);

	/* Fetch bootfile path */
	if ((cp = getenv("bootfile")) != NULL) {
		loadaddr = load_bin(cp, 1);
		if (loadaddr != NULL)
			strcpy(execpath, cp);
	}

	/* Fallback if bootfile not set or couldn't be loaded */
	for (i = 0; loadaddr == NULL && bootfiles[i] != NULL; i++) {
		loadaddr = load_bin(bootfiles[i], 1);
		if (loadaddr != NULL)
			strcpy(execpath, bootfiles[i]);
	}

	/* Opportunity to escape to a file chooser prompt */
	if (loadaddr != NULL && (cp = getenv("autoboot_delay")) != NULL) {
		clock_gettime(CLOCK_MONOTONIC, &tv0);
		for (i = atoi(cp); i > 0; i--) {
			printf("\rBooting in %d s...%c\b", i, "|/-\\"[i & 0x3]);
			do {
				c = sio_getchar(0);
				if (c == 27) {
					/* ESC = break to prompt */
					loadaddr = NULL;
					break;
				}
				if (c == 'b') {
					/* Skip the long wait... */
					i = 0;
					break;
				}
				clock_gettime(CLOCK_MONOTONIC, &tv1);
			} while ((tv1.tv_sec == tv0.tv_sec ||
			    tv1.tv_nsec < tv0.tv_nsec) && loadaddr != NULL);
			tv0.tv_sec = tv1.tv_sec;
		}
		printf(" \n");
	}

	/* All load attempts so far have failed, pick the file interactively */
	while (loadaddr == NULL) {
		printf("File to boot: ");
		cp = gets_s(execpath, sizeof(execpath));
		if (cp == NULL) {
			/* XXX FIXME: unreachable due to ISIG SIGINT */
			f32c_eip->cookie = F32C_EXECINFO_NOBOOT;
			return;
		}
		loadaddr = load_bin(execpath, 1);
	}

	/* Ditch the boot environment and load the application env */
	if ((cp = getenv("envfile")) != NULL)
		loadenv(cp);

	/* alloca()te and populate argv and envp, C/P from execve() */
	size = strlen(execpath) + 1;
	for (envc = 0; environ[envc] != NULL; envc++)
		size += strlen(environ[envc]) + 1;
	envc++;
	size = (size + 3) & ~3;
	size += sizeof(char *);
	size += envc * sizeof(char *);
	argv = alloca(size);
	envp = &argv[1];
	cp = (void *) &envp[envc];
	strcpy(cp, execpath);
	argc = 1;
	argv[0] = cp;
	cp += strlen(cp) + 1;
	for (envc = 0; environ[envc] != NULL; envc++) {
		strcpy(cp, environ[envc]);
		envp[envc] = cp;
		cp += strlen(cp) + 1;
	}
	envp[envc] = NULL;
	while ((((int) cp) & 0x3) != 0)
		*cp++ = 0;

boot:
	/* If __memtop is set, propagate it to the executable */
	if (__memtop != 0) {
		uint32_t *loadinfo = loadaddr;

		loadinfo[0] = 0xf32cf00d;
		loadinfo[1] = (uint32_t) __memtop;
		loadinfo[2] = (uint32_t) __ramdisk;
		loadaddr = (void *) &loadinfo[3];
		if (loadaddr < __memtop)
			sp = __memtop;
	}

	/* Invalidate I-cache */
#ifdef __mips__
	for (i = 0x80000000; i < 0x80010000; i += 4) {
		__asm __volatile__(
			"cache 0, 0(%0)"
			: 
			: "r" (i)
		);
	}
#else /* riscv */
	__asm __volatile__(
		"fence.i;"		/* flush I-cache */
	);
#endif

	/* Turn off video framebuffer and PCM audio DMA */
	OUTW(IO_LED, 0);	/* LEDs off */
	OUTW(IO_FB, 3);		/* framebuffer off */
	OUTW(IO_PCM_FREQ, 0);	/* stop PCM DMA */
	OUTW(IO_PCM_VOLUME, 0);	/* mute PCM DAC output */

	__asm __volatile__(
#ifdef __mips__
		".set noat;"
		"move $1, %4;"	/* at */
		"move $4, %0;"	/* a0 */
		"move $5, %1;"	/* a1 */
		"move $6, %2;"	/* a2 */
		"move $29, %3;"	/* sp */
		"move $31, $0;" /* ra */
		"jr $1;"
		".set at;"
#else /* riscv */
		"move t0, %4;"
		"move a0, %0;"
		"move a1, %1;"
		"move a2, %2;"
		"move sp, %3;"
		"move ra, zero;"
		"jr t0;"
#endif
		:
		: "r" (argc), "r" (argv), "r" (envp), "r" (sp), "r" (loadaddr)
	);
}
