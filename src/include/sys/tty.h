/*-
 * Copyright (c) 2025 Marko Zec
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS_TTY_H_
#define _SYS_TTY_H_

#include <termios.h>

#define	TTY_OSTOP	0x0001
#define	TTY_IGOTCR	0x0010

#define TTY_OBLOCKED(t) ((t) != NULL && ((t)->t_rflags & TTY_OSTOP))

#define TTY_DO_IPROC(t, c) ((t) != NULL && ((c) < 32 || (c) > 126 || (t->t_rflags & TTY_IGOTCR)))
#define TTY_DO_OPROC(t, c) ((t) != NULL && ((uint) c) < 32)

struct tty {
	struct termios	t_termios;
	struct winsize	t_ws;
	uint16_t	t_rflags;
};

int tty_iproc(struct tty *, int);
int tty_oexpand(struct tty *, int, char *);

#endif /* _SYS_TTY_H_ */
