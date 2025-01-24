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

#include <fcntl.h>
#include <stdlib.h>

#include <sys/file.h>

extern int fd_ref(struct file *); /* XXX fixinclude */
 
static int pipe_read(struct file *, void *, size_t);
static int pipe_write(struct file *, const void *, size_t);

static struct fileops pipe_fileops = {
	.fo_read = &pipe_read,
	.fo_write = &pipe_write,
};

#define	PIPE_BUFSIZE   (1 << 8)
#define	PIPE_BUFMASK   (PIPE_BUFSIZE - 1)

struct pipe_state {
	uint16_t	s_buf_head; /* Managed by pipe_write() */
	uint16_t	s_buf_tail; /* Managed by pipe_read() */
	char		s_buf[PIPE_BUFSIZE];
};

int
pipe(int *fd)
{
	struct file *fp;
	struct pipe_state *pipe;

	if ((pipe = calloc(1, sizeof(struct pipe_state))) == NULL) {
		errno = ENOMEM;
		return (-1);
	}

	fp = calloc(1, sizeof(struct file));
	fd[0] = fd_ref(fp);
	fd[1] = fd_ref(fp);
	if (fd[0] < 0 || fd[1] < 0) {
		free(fp);
		free(pipe);
		errno = ENFILE;
		return (-1);
	}

	fp->f_priv = pipe;
	fp->f_mflags = F_MF_FILE_MALLOCED | F_MF_PRIV_MALLOCED;
	fp->f_ops = &pipe_fileops;

	return (0);
}

static int
pipe_write(struct file *fp, const void *buf, size_t nbytes)
{
	struct task *task = TD_TASK(curthread);
	struct pipe_state *pipe = fp->f_priv;
	const char *cp = buf;
	int i;
	int buf_head_next;
	int buf_full;

	for (i = 0; i < nbytes; i++) {
		for (;;) {
			buf_head_next = (pipe->s_buf_head + 1) & PIPE_BUFMASK;
			buf_full = buf_head_next == pipe->s_buf_tail;
			if (!buf_full)
				break;
			if (fp->f_refc < 2) {
				errno = EPIPE;
				return (-1);
			}
			if (fp->f_flags & O_NONBLOCK) {
				if (i != 0)
					return (i);
				errno = EAGAIN;
				return (-1);
			}
			if (task->ts_sigf & 2) {
				errno = EINTR;
				task->ts_sigf &= ~2;
				return (-1);
			}
			/* XXX TODO: notify system we are blocked, yield() */
		}
		pipe->s_buf[pipe->s_buf_head] = *cp++;
		pipe->s_buf_head = buf_head_next;
	}

	return (0);
}

static int
pipe_read(struct file *fp, void *buf, size_t nbytes)
{
	struct task *task = TD_TASK(curthread);
	struct pipe_state *pipe = fp->f_priv;
	char *cp = buf;
	int i, empty;

	for (i = 0; i < nbytes;) {
		for (;;) {
			empty = pipe->s_buf_head == pipe->s_buf_tail;
			if (!empty)
				break;
			if (fp->f_refc < 2)
				return (0);
			if (fp->f_flags & O_NONBLOCK) {
				if (i != 0)
					return (i);
				errno = EAGAIN;
				return (-1);
			}
			if (task->ts_sigf & 2) {
				errno = EINTR;
				task->ts_sigf &= ~2;
				return (-1);
			}
			/* XXX TODO: notify system we are blocked, yield() */
		}
		do {
			cp[i++] = pipe->s_buf[pipe->s_buf_tail++];
			pipe->s_buf_tail &= PIPE_BUFMASK;
			empty = pipe->s_buf_head == pipe->s_buf_tail;
		} while (!empty && i < nbytes);
	}

	return (i);
}
