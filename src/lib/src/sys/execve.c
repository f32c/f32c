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
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/exec.h>


extern void *__memtop;
extern void *__ramdisk;


int
execve(const char *path, char *const argv[], char *const envp[])
{
	int argc, envc, size, i;
	char **xargv, **xenvp;
	char *cp;
	struct f32c_execinfo *f32c_eip;

	int fd;

	fd = open(path, O_RDONLY);
	if (fd < 0)
		return (-1);
	close(fd);

	size = strlen(path) + 1;
	for (argc = 0; argv != NULL && argv[argc] != NULL; argc++)
		size += strlen(argv[argc]) + 1;
	argc++;
	for (envc = 0; envp != NULL && envp[envc] != NULL; envc++)
		size += strlen(envp[envc]) + 1;
	envc++;
	size = (size + 3) & ~3;
	size += argc * sizeof(char *);
	size += envc * sizeof(char *);

	/* 
	 * XXX 1st stage bootloader uses some 0.5 kB of stack space, so
	 * make a slightly bigger stack allocation just to be sure our
	 * args and env do not get clobbered on the bootloader's stack.
	 */
	xargv = alloca(size + 768);
	xenvp = &xargv[argc];
	cp = (void *) &xenvp[envc];

	strcpy(cp, path);
	xargv[0] = cp;
	cp += strlen(cp) + 1;
	for (i = 1; i < argc; i++) {
		strcpy(cp, argv[i - 1]);
		xargv[i] = cp;
		cp += strlen(cp) + 1;
	}
	for (envc = 0; envp != NULL && envp[envc] != NULL; envc++) {
		strcpy(cp, envp[envc]);
		xenvp[envc] = cp;
		cp += strlen(cp) + 1;
	}
	xenvp[envc] = NULL;
	while ((((int) cp) & 0x3) != 0)
		*cp++ = 0;

	f32c_eip = (void *) F32C_EXECINFO_ADDR;
	f32c_eip->cookie = F32C_EXECINFO_COOKIE;
	f32c_eip->tries = 0;
	f32c_eip->memtop = __memtop;
	f32c_eip->ramdisk = __ramdisk;
	f32c_eip->size = size;
	f32c_eip->argc = argc;
	f32c_eip->argv = xargv;
	f32c_eip->envp = xenvp;

	exit(0);
}
