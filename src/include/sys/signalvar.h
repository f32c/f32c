/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)signalvar.h	8.6 (Berkeley) 2/19/95
 */

#ifndef _SYS_SIGNALVAR_H_
#define	_SYS_SIGNALVAR_H_

#include <sys/queue.h>
#include <sys/signal.h>

/*
 * Kernel signal definitions and data structures.
 */

/*
 * Logical process signal actions and state, needed only within the process
 * The mapping between sigacts and proc structures is 1:1 except for rfork()
 * processes masquerading as threads which use one structure for the whole
 * group.  All members are locked by the included mutex.  The reference count
 * and mutex must be last for the bcopy in sigacts_copy() to work.
 */
struct sigacts {
	sig_t	ps_sigact[_SIG_MAXSIG];	/* Disposition of signals. */
};

#define	PS_NOCLDWAIT	0x0001	/* No zombies if child dies */
#define	PS_NOCLDSTOP	0x0002	/* No SIGCHLD when children stop. */
#define	PS_CLDSIGIGN	0x0004	/* The SIGCHLD handler is SIG_IGN. */

#ifdef _KERNEL

/* additional signal action values, used only temporarily/internally */
#define	SIG_CATCH	((__sighandler_t *)2)
/* #define SIG_HOLD        ((__sighandler_t *)3) See signal.h */

/*
 * get signal action for process and signal; currently only for current process
 */
#define	SIGACTION(p, sig)	(p->p_sigacts->ps_sigact[_SIG_IDX(sig)])

#endif /* _KERNEL */

/*
 * sigset_t manipulation macros.
 */
#define	SIGADDSET(set, signo)						\
	((set).__bits[_SIG_WORD(signo)] |= _SIG_BIT(signo))

#define	SIGDELSET(set, signo)						\
	((set).__bits[_SIG_WORD(signo)] &= ~_SIG_BIT(signo))

#define	SIGEMPTYSET(set)						\
	do {								\
		int __i;						\
		for (__i = 0; __i < _SIG_WORDS; __i++)			\
			(set).__bits[__i] = 0;				\
	} while (0)

#define	SIGFILLSET(set)							\
	do {								\
		int __i;						\
		for (__i = 0; __i < _SIG_WORDS; __i++)			\
			(set).__bits[__i] = ~0U;			\
	} while (0)

#define	SIGISMEMBER(set, signo)						\
	((set).__bits[_SIG_WORD(signo)] & _SIG_BIT(signo))

#define	SIGISEMPTY(set)		(__sigisempty(&(set)))
#define	SIGNOTEMPTY(set)	(!__sigisempty(&(set)))

#define	SIGSETEQ(set1, set2)	(__sigseteq(&(set1), &(set2)))
#define	SIGSETNEQ(set1, set2)	(!__sigseteq(&(set1), &(set2)))

#define	SIGSETOR(set1, set2)						\
	do {								\
		int __i;						\
		for (__i = 0; __i < _SIG_WORDS; __i++)			\
			(set1).__bits[__i] |= (set2).__bits[__i];	\
	} while (0)

#define	SIGSETAND(set1, set2)						\
	do {								\
		int __i;						\
		for (__i = 0; __i < _SIG_WORDS; __i++)			\
			(set1).__bits[__i] &= (set2).__bits[__i];	\
	} while (0)

#define	SIGSETNAND(set1, set2)						\
	do {								\
		int __i;						\
		for (__i = 0; __i < _SIG_WORDS; __i++)			\
			(set1).__bits[__i] &= ~(set2).__bits[__i];	\
	} while (0)

#define	SIGSETLO(set1, set2)	((set1).__bits[0] = (set2).__bits[0])
#define	SIGSETOLD(set, oset)	((set).__bits[0] = (oset))

#define	SIG_CANTMASK(set)						\
	SIGDELSET(set, SIGKILL), SIGDELSET(set, SIGSTOP)

#define	SIG_STOPSIGMASK(set)						\
	SIGDELSET(set, SIGSTOP), SIGDELSET(set, SIGTSTP),		\
	SIGDELSET(set, SIGTTIN), SIGDELSET(set, SIGTTOU)

#define	SIG_CONTSIGMASK(set)						\
	SIGDELSET(set, SIGCONT)

#define	sigcantmask	(sigmask(SIGKILL) | sigmask(SIGSTOP))

#define	SIG2OSIG(sig, osig)	(osig = (sig).__bits[0])
#define	OSIG2SIG(osig, sig)	SIGEMPTYSET(sig); (sig).__bits[0] = osig

static __inline int
__sigisempty(sigset_t *set)
{
	int i;

	for (i = 0; i < _SIG_WORDS; i++) {
		if (set->__bits[i])
			return (0);
	}
	return (1);
}

static __inline int
__sigseteq(sigset_t *set1, sigset_t *set2)
{
	int i;

	for (i = 0; i < _SIG_WORDS; i++) {
		if (set1->__bits[i] != set2->__bits[i])
			return (0);
	}
	return (1);
}

typedef struct sigqueue {
	sigset_t	sq_signals;	/* All pending signals. */
} sigqueue_t;

/* Flags for ksi_flags */
#define	SQ_INIT	0x01

/*
 * Fast_sigblock
 */
#define	SIGFASTBLOCK_SETPTR	1
#define	SIGFASTBLOCK_UNBLOCK	2
#define	SIGFASTBLOCK_UNSETPTR	3

#define	SIGFASTBLOCK_PEND	0x1
#define	SIGFASTBLOCK_FLAGS	0xf
#define	SIGFASTBLOCK_INC	0x10

#ifndef _KERNEL
int __sys_sigfastblock(int cmd, void *ptr);
#endif

//#ifdef _KERNEL
extern bool sigfastblock_fetch_always;
extern bool pt_attach_transparent;

/* Return nonzero if process p has an unmasked pending signal. */
#define	SIGPENDING(td)							\
	(!SIGISEMPTY((td)->td_siglist) &&				\
	    !sigsetmasked(&(td)->td_siglist, &(td)->td_sigmask))
/*
 * Return the value of the pseudo-expression ((*set & ~*mask) == 0).  This
 * is an optimized version of SIGISEMPTY() on a temporary variable
 * containing SIGSETNAND(*set, *mask).
 */
static __inline bool
sigsetmasked(sigset_t *set, sigset_t *mask)
{
	int i;

	for (i = 0; i < _SIG_WORDS; i++) {
		if (set->__bits[i] & ~mask->__bits[i])
			return (false);
	}
	return (true);
}

struct pgrp;
struct sigio;
struct thread;

/* Flags for kern_sigprocmask(). */
#define	SIGPROCMASK_OLD		0x0001
#define	SIGPROCMASK_PROC_LOCKED	0x0002
#define	SIGPROCMASK_PS_LOCKED	0x0004
#define	SIGPROCMASK_FASTBLK	0x0008

/*
 * Modes for sigdeferstop().  Manages behaviour of
 * thread_suspend_check() in the region delimited by
 * sigdeferstop()/sigallowstop().  Must be restored to
 * SIGDEFERSTOP_OFF before returning to userspace.
 */
#define	SIGDEFERSTOP_NOP	0 /* continue doing whatever is done now */
#define	SIGDEFERSTOP_OFF	1 /* stop ignoring STOPs */
#define	SIGDEFERSTOP_SILENT	2 /* silently ignore STOPs */
#define	SIGDEFERSTOP_EINTR	3 /* ignore STOPs, return EINTR */
#define	SIGDEFERSTOP_ERESTART	4 /* ignore STOPs, return ERESTART */

#define	SIGDEFERSTOP_VAL_NCHG	(-1) /* placeholder indicating no state change */
int	sigdeferstop_impl(int mode);
void	sigallowstop_impl(int prev);

static inline int
sigdeferstop(int mode)
{

	if (__predict_false(mode == SIGDEFERSTOP_NOP))
		return (SIGDEFERSTOP_VAL_NCHG);
	return (sigdeferstop_impl(mode));
}

static inline void
sigallowstop(int prev)
{

	if (__predict_true(prev == SIGDEFERSTOP_VAL_NCHG))
		return;
	sigallowstop_impl(prev);
}

//#endif /* _KERNEL */

/* f32c hacks */
void sig_dispatch(void);

#endif /* !_SYS_SIGNALVAR_H_ */
