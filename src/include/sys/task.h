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

#ifndef _SYS_TASK_H_
#define _SYS_TASK_H_

#include <signal.h>

#include <sys/queue.h>

struct task {
	struct file	**ts_files;	/* Array of file pointers */
	int		ts_maxfiles;	/* Size of ts_files */
	void		*ts_stdin;	/* stdin */
	void		*ts_stdout;	/* stdout */
	void		*ts_stderr;	/* stderr */
	TAILQ_HEAD(, thread) ts_tds;	/* List of this task's threads */
	TAILQ_ENTRY(task) ts_list;	/* All tasks linked list */
	struct task	*ts_parent;	/* Parent task */
	sig_t		ts_sigh;	/* Signal handler */
	uint32_t	ts_sigf;	/* Signal flags */
};

struct thread {
	void		*td_retaddr;	/* Jump there on exit. Do not move */
	TAILQ_ENTRY(thread) td_list;	/* Owner task's threads linked list */
	struct task	*td_task;	/* Owner task */
	int		td_errno;	/* Last error */
	struct regspace	*td_regs;	/* Saved register state */
	char		*td_stackb;	/* Bottom of the stack space */
	uint16_t	td_inhibitors;	/* Why can not run */
	uint16_t	td_spare1;	/* alignment */
};

/*
 * Reasons that the current thread can not be run yet.
 * More than one may apply.
 */
#define	TDI_SUSPENDED	0x0001		/* On suspension queue. */
#define	TDI_SLEEPING	0x0002		/* Actually asleep! (tricky). */
#define	TDI_YIELDED	0x0004		/* Inside sched_yield() call. */
#define	TDI_IWAIT	0x0010		/* Awaiting interrupt. */

extern struct task task0;
extern struct thread thread0;

inline __pure2 struct thread *
__curthread(void)
{
	struct thread *td;

#ifdef __mips__
	__asm("addu %0, $27, $0" : "=&r"(td));
#else /* __riscv__ */
	__asm("mv %0, tp" : "=&r"(td));
#endif
	return (td);
}

#define	curthread	(__curthread())

#define	TD_TASK(td)	(td)->td_task

struct task *task_alloc(size_t);
void task_free(struct task *);

#endif /* _SYS_TASK_H_ */
