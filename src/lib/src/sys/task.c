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
	.ts_stdin = &__stdin,
	.ts_stdout = &__stdout,
	.ts_stderr = &__stderr,
};

struct thread thread0 = {
	.td_task = &task0,
	.td_list.tqe_prev = &task0.ts_tds.tqh_first /* Thread list elem init */
};


void
thread_free(struct thread *td)
{

	TAILQ_REMOVE(&td->td_task->ts_tds, td, td_list);
	free(td->td_stackb);
	free(td);
}


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

	TAILQ_INSERT_TAIL(&ts->ts_tds, td, td_list);
	td->td_task = ts;
	td->td_stackb = stack;

	return (td);
}


void
task_free(struct task *ts)
{
	struct file *fp;
	struct thread *td;
	int i;

	/* Free all threads */
	do {
		td = TAILQ_FIRST(&ts->ts_tds);
		if (td != NULL)
			thread_free(td);
	} while (td != NULL);

	/* Close open files */
	for (i = 0; i < ts->ts_maxfiles; i++) {
		fp = ts->ts_files[i];
		if (fp == NULL)
			continue;
		if (--(fp->f_refc))
			continue;
		fp->f_ops->fo_close(fp);
		free(fp->f_priv);
		free(fp);
	}

	free(ts->ts_files);
	free(ts->ts_stdin);
	free(ts->ts_stdout);
	free(ts->ts_stderr);
	TAILQ_REMOVE(&tasks, ts, ts_list);
	free(ts);
}


struct task *
task_alloc(size_t stacksiz)
{
	struct task *curts = TD_TASK(curthread);
	struct task *ts;
	int i;

	/* Allocate task structure */
	ts = calloc(1, sizeof(*ts));
	if (ts == NULL)
		return(NULL);

	/* Allocate file descriptor table */
	ts->ts_maxfiles = curts->ts_maxfiles;
	ts->ts_files = calloc(ts->ts_maxfiles, sizeof(struct file));
	if (ts->ts_files == NULL) {
		free(ts);
		return(NULL);
	}

	/* Allocate the main thread */
	TAILQ_INIT(&ts->ts_tds);
	thread_alloc(ts, stacksiz);
	if (TAILQ_EMPTY(&ts->ts_tds)) {
		free(ts);
		return(NULL);
	}

	/* Link into the all tasks lists */
	TAILQ_INSERT_TAIL(&tasks, ts, ts_list);
	ts->ts_parent = curts;

	/* Reference open files */
	for (i = 0; i < ts->ts_maxfiles; i++) {
		if (ts->ts_files[i] == NULL)
			continue;
		ts->ts_files[i] = curts->ts_files[i];
		ts->ts_files[i]->f_refc++;
	}

	/* Allocate stdin, stdout, stderr */
	ts->ts_stdin = calloc(1, sizeof(FILE));
	ts->ts_stdout = calloc(1, sizeof(FILE));
	ts->ts_stderr = calloc(1, sizeof(FILE));

	if (ts->ts_stdin == NULL || ts->ts_stdout == NULL
	    || ts->ts_stderr == NULL) {
		task_free(ts);
		return(NULL);
	}
	((FILE *) ts->ts_stdin)->_fd = 0;
	((FILE *) ts->ts_stdout)->_fd = 1;
	((FILE *) ts->ts_stderr)->_fd = 2;

	return(ts);
}


int
atexit(void (*function)(void))
{

	/* XXX fixme */
	return (0);
}


/* XXX exit() works only on CPU #0 - fixme! */
#pragma weak exit
_Noreturn void
exit(int x __unused)
{

	while (1) {
		__asm __volatile (
#ifdef __mips__
			".set noreorder\n"
			"lw $31, 0($27)\n" /* Restore return address */
			"jr $31\n"	/* ra */
			"mtc0 $0, $12\n" /* Mask and disable all interrupts */
			".set reorder"
#else /* riscv */
			"lw ra, 0(tp)\n" /* Restore return address */
			"jr ra\n"
#endif
		);
	}
}
