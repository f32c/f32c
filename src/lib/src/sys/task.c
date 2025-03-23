/*-
 * Copyright (c) 2024 Marko Zec
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

#include <stdio.h>
#include <stdlib.h>

#include <sys/file.h>
#include <sys/queue.h>

extern struct file __sio0_file;

static struct file *stdfiles[3] = {
	&__sio0_file, &__sio0_file, &__sio0_file
};

static FILE __stdin = { ._fd = 0 };
static FILE __stdout = { ._fd = 1 };
static FILE __stderr = { ._fd = 2 };

/* List of all tasks */
TAILQ_HEAD(, task) tasks = {
	.tqh_first = &task0,			/* Tasks head init */
	.tqh_last = &task0.ts_list.tqe_next	/* Tasks head init */
};

struct task task0 = {
	.ts_tds.tqh_first = &thread0,		/* Threads head init */
	.ts_tds.tqh_last = &thread0.td_list.tqe_next, /* Threads head init */
	.ts_list.tqe_prev = &tasks.tqh_first,	/* Tasks list elem init */
	.ts_files = stdfiles,
	.ts_maxfiles = 3,
	.ts_stdin = &__stdin,
	.ts_stdout = &__stdout,
	.ts_stderr = &__stderr,
};

struct thread thread0 = {
	.td_task = &task0,
	.td_list.tqe_prev = &task0.ts_tds.tqh_first /* Thread list elem init */
};


struct thread *
thread_alloc(struct task *ts, size_t stacksiz)
{
	struct thread *td;
	char *stack;

	td = calloc(1, sizeof(*td));
	stack = malloc(stacksiz);
	if (td == NULL || stack == NULL) {
		free(td);
		free(stack);
		return (NULL);
	}

	TAILQ_INSERT_HEAD(&ts->ts_tds, td, td_list);
	td->td_task = ts;
	td->td_stackb = stack;

	return (td);
}


struct task *
task_alloc(void)
{
	struct task *ts;

	ts = calloc(1, sizeof(*ts));
	if (ts == NULL)
		return(NULL);

	ts->ts_maxfiles = 4;
	ts->ts_files = calloc(ts->ts_maxfiles, sizeof(struct file));
	ts->ts_stdin = calloc(1, sizeof(FILE));
	ts->ts_stdout = calloc(1, sizeof(FILE));
	ts->ts_stderr = calloc(1, sizeof(FILE));

	if (ts->ts_files == NULL || ts->ts_stdin == NULL
	    || ts->ts_stdout == NULL || ts->ts_stderr == NULL) {
		free(ts->ts_files);
		free(ts->ts_stdin);
		free(ts->ts_stdout);
		free(ts->ts_stderr);
		free(ts);
		return(NULL);
	}
	TAILQ_INSERT_TAIL(&tasks, ts, ts_list);
	ts->ts_parent = TD_TASK(curthread);
	((FILE *) ts->ts_stdin)->_fd = 0;
	((FILE *) ts->ts_stdout)->_fd = 1;
	((FILE *) ts->ts_stderr)->_fd = 2;

	return(ts);
}
