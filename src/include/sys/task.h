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

#include <sys/queue.h>

struct regspace;
struct file;

struct task {
	struct file	**ts_files;	/* Array of file pointers */
	int		ts_maxfiles;	/* Size of ts_files */
	TAILQ_HEAD(, thread) ts_tds;	/* List of this task's threads */
	TAILQ_ENTRY(task) ts_list;	/* All tasks linked list */
	struct task	*ts_parent;	/* Parent task */
};

struct thread {
	TAILQ_ENTRY(thread) td_list;	/* Owner task's threads linked list */
	struct task	*td_task;	/* Owner task */
	int		td_errno;	/* Last error */
	struct regspace	*td_regs;	/* Saved register state */
};

extern struct task task0;
extern struct thread thread0;

inline void
curthread_set(struct thread *td)
{
#ifdef __mips__
	__asm __volatile("addu $27, $0, %0" :: "r" (td));
#else /* __riscv__ */
	__asm __volatile("mv tp, %0" :: "r" (td));
#endif
}

inline struct thread *
curthread_get(void)
{
	struct thread *td;

#ifdef __mips__
	__asm __volatile("addu %0, $27, $0" : "=&r"(td));
#else /* __riscv__ */
	__asm __volatile("mv %0, tp" : "=&r"(td));
#endif

	return (td);
}

#define	curthread	curthread_get()

#endif /* _SYS_TASK_H_ */
