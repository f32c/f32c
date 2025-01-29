/*-
 * Copyright (c) 2013 - 2025 Marko Zec
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

#include <signal.h>

#include <sys/tty.h>

/*
 * termios output processing:
 *
 * ONLCR	Map NL to CR-NL on output.
 */

int
tty_oexpand(struct tty *tty, int c, char *buf)
{
	int n = 1;

	switch(c) {
	case '\n':
		if (tty->t_termios.c_oflag & ONLCR) {
			*buf++ = '\r';
			n++;
		}
		/* fallthrough */
	default:
		*buf = c;
	};

	return (n);
}


/*
 * termios input processing
 */

int
tty_iproc(struct tty *tty, int c)
{
	struct task *task;
	sig_t sigh;

	switch(c) {
	case 0x3: /* CTRL+C */
		if (tty->t_termios.c_lflag & ISIG) {
			task = TD_TASK(curthread);
			sigh = task->ts_sigh;
			if (sigh != NULL) {
				sigh(SIGINT);
				/* Notify stalled read() / write() */
				task->ts_sigf |= (task->ts_sigf & 1) << 1;
			}
			return (-1);
		} else
			return (c);
	case 0x13: /* XOFF */
		if (tty->t_termios.c_iflag & IXON) {
			tty->t_rflags |= TTY_OSTOP;
			return (-1);
		} else
			return (c);
	case 0x11: /* XON */
		if (tty->t_termios.c_iflag & IXON) {
			tty->t_rflags &= ~TTY_OSTOP;
			return (-1);
		} else
			return (c);
	default:
		return (c);
	}
}
