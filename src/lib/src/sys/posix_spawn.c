/*-
 * Copyright (c) 2026 Marko Zec
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
#include <unistd.h>

extern void *__memtop;
extern void *__ramdisk;
extern void _start(void);

typedef int _start_t(int, char *const [], char *const []);

uint32_t __spawn_regstore[16];


pid_t
waitpid(pid_t wpid, int *status, int options)
{

	/* XXX just a placeholder function, we don't wait, we do nothing */
	return (0);
}


int
posix_spawn(int *cpid, const char *path, void *fa __unused, void *at __unused,
    char *const argv[], char *const envp[])
{
	uint8_t hdrbuf[40];
	int32_t *longp = (void *) hdrbuf;
#ifdef __mips__
	int16_t *shortp = (void *) hdrbuf;
#endif
	void *childsp = &_start;
	int i, fd, argc;
	void *start, *bss, *end;
	char *cp;
	_start_t *entry;

	for (argc = 0; argv[argc] != NULL; argc++) {}

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return (-1);
	i = read(fd, hdrbuf, sizeof(hdrbuf));
	close(fd);
	if (i != sizeof(hdrbuf)) {
		errno = ENOEXEC;
		return (-1);
	}

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
		errno = ENOEXEC;
		return (-1);
	}

	if (bss <= start || end <= bss) {
		errno = ENOEXEC;
		return (-1);
	}

	if (end >= (void *) &_start) {
		errno = ENOMEM;
		return (-1);
	}

	fd = open(path, O_RDONLY);
	cp = start;
	do {
		i = read(fd, cp, 65536);
		cp += i;
	} while (i > 0 && cp < (char *) bss);
	close(fd);

	if ((char *) bss < cp || (char *) bss > cp + 4) {
		errno = ENOEXEC;
		return (-1);
	}

	/* Propagate memtop, __ramdisk to the executable */
	longp = start;
	longp[0] = 0xf32cf00d;
	longp[1] = (uint32_t) childsp; /* to become __memtop in child */
	longp[2] = (uint32_t) __ramdisk;
	entry = (void *) &longp[3];

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

	/* Store caller-preserved registers in a dedicated block */
        __asm __volatile__(
#ifdef __mips__
		"la $12, __spawn_regstore;" 	/* t0 */
		"sw $16, (0 * 4)($12);"		/* s0 */
		"sw $17, (1 * 4)($12);"		/* s1 */
		"sw $18, (2 * 4)($12);"		/* s2 */
		"sw $19, (3 * 4)($12);"		/* s3 */
		"sw $20, (4 * 4)($12);"		/* s4 */
		"sw $21, (5 * 4)($12);"		/* s5 */
		"sw $22, (6 * 4)($12);"		/* s6 */
		"sw $23, (7 * 4)($12);"		/* s7 */
		"sw $30, (8 * 4)($12);"		/* s8 */
		"sw $27, (9 * 4)($12);"		/* k1 == tp */
		"sw $29, (10 * 4)($12);"	/* sp */
		"sw $28, (11 * 4)($12);"	/* gp */
		"sw $30, (12 * 4)($12);"	/* fp */
		"move $29, %0;"			/* Set child sp */
		"move $2, %1;"			/* v0 = entry */
		"move $4, %2;"			/* a0 = argc */
		"move $5, %3;"			/* a1 = argv */
		"move $6, %4;"			/* a2 = envp */
		"jalr $2;"
		/* Restore caller-preserved registers from a dedicated block */
		"lui $12, %%hi(__spawn_regstore);" /* t0, hi */
		"addiu $12, $12, %%lo(__spawn_regstore);" /* t0, lo */
		"lw $16, (0 * 4)($12);"		/* s0 */
		"lw $17, (1 * 4)($12);"		/* s1 */
		"lw $18, (2 * 4)($12);"		/* s2 */
		"lw $19, (3 * 4)($12);"		/* s3 */
		"lw $20, (4 * 4)($12);"		/* s4 */
		"lw $21, (5 * 4)($12);"		/* s5 */
		"lw $22, (6 * 4)($12);"		/* s6 */
		"lw $23, (7 * 4)($12);"		/* s7 */
		"lw $30, (8 * 4)($12);"		/* s8 */
		"lw $27, (9 * 4)($12);"		/* k1 == tp */
		"lw $29, (10 * 4)($12);"	/* sp */
		"lw $28, (11 * 4)($12);"	/* gp */
		"lw $30, (12 * 4)($12);"	/* fp */
#else /* riscv */
		"la t0, __spawn_regstore;"
		"sw s0, (0 * 4)(t0);"
		"sw s1, (1 * 4)(t0);"
		"sw s2, (2 * 4)(t0);"
		"sw s3, (3 * 4)(t0);"
		"sw s4, (4 * 4)(t0);"
		"sw s5, (5 * 4)(t0);"
		"sw s6, (6 * 4)(t0);"
		"sw s7, (7 * 4)(t0);"
		"sw s8, (8 * 4)(t0);"
		"sw s9, (9 * 4)(t0);"
		"sw s10, (10 * 4)(t0);"
		"sw s11, (11 * 4)(t0);"
		"sw tp, (12 * 4)(t0);"
		"sw sp, (13 * 4)(t0);"
		"sw gp, (14 * 4)(t0);"
		"sw fp, (15 * 4)(t0);"
		"move sp, %0;"			/* Set child sp */
		"move t0, %1;"			/* t0 = entry */
		"move a0, %2;"			/* a0 = argc */
		"move a1, %3;"			/* a1 = argv */
		"move a2, %4;"			/* a2 = envp */
		"jalr t0;"
		/* Restore caller-preserved registers from a dedicated block */
		".option norelax;"
		"lui t0, %%hi(__spawn_regstore);"
		"addi t0, t0, %%lo(__spawn_regstore);"
		".option relax;"
		"lw s0, (0 * 4)(t0);"
		"lw s1, (1 * 4)(t0);"
		"lw s2, (2 * 4)(t0);"
		"lw s3, (3 * 4)(t0);"
		"lw s4, (4 * 4)(t0);"
		"lw s5, (5 * 4)(t0);"
		"lw s6, (6 * 4)(t0);"
		"lw s7, (7 * 4)(t0);"
		"lw s8, (8 * 4)(t0);"
		"lw s9, (9 * 4)(t0);"
		"lw s10, (10 * 4)(t0);"
		"lw s11, (11 * 4)(t0);"
		"lw tp, (12 * 4)(t0);"
		"lw sp, (13 * 4)(t0);"
		"lw gp, (14 * 4)(t0);"
		"lw fp, (15 * 4)(t0);"
#endif
                :
                : "r" (childsp), "r" (entry), "r" (argc), "r" (argv), "r" (envp)
        );

	return(0);
}
