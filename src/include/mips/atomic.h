/*-
 * Copyright (c) 1998 Doug Rabson
 * All rights reserved.
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
 *
 *	from: src/sys/alpha/include/atomic.h,v 1.21.2.3 2005/10/06 18:12:05 jhb
 * $FreeBSD: head/sys/mips/include/atomic.h 222234 2011-05-23 23:35:50Z attilio $
 */

#ifndef _MACHINE_ATOMIC_H_
#define	_MACHINE_ATOMIC_H_

#ifndef _SYS_CDEFS_H_
#error this file needs sys/cdefs.h as a prerequisite
#endif


static __inline void
atomic_set_32(__volatile uint32_t *p, uint32_t v)
{
	uint32_t temp;

	__asm __volatile (
		"1:\tll	%0, %3\n\t"		/* load old value */
		"or	%0, %2, %0\n\t"		/* calculate new value */
		"sc	%0, %1\n\t"		/* attempt to store */
		"beqz	%0, 1b\n\t"		/* spin if failed */
		: "=&r" (temp), "=m" (*p)
		: "r" (v), "m" (*p)
		: "memory");
}

static __inline void
atomic_clear_32(__volatile uint32_t *p, uint32_t v)
{
	uint32_t temp;
	v = ~v;

	__asm __volatile (
		"1:\tll	%0, %3\n\t"		/* load old value */
		"and	%0, %2, %0\n\t"		/* calculate new value */
		"sc	%0, %1\n\t"		/* attempt to store */
		"beqz	%0, 1b\n\t"		/* spin if failed */
		: "=&r" (temp), "=m" (*p)
		: "r" (v), "m" (*p)
		: "memory");
}

static __inline void
atomic_add_32(__volatile uint32_t *p, uint32_t v)
{
	uint32_t temp;

	__asm __volatile (
		"1:\tll	%0, %3\n\t"		/* load old value */
		"addu	%0, %2, %0\n\t"		/* calculate new value */
		"sc	%0, %1\n\t"		/* attempt to store */
		"beqz	%0, 1b\n\t"		/* spin if failed */
		: "=&r" (temp), "=m" (*p)
		: "r" (v), "m" (*p)
		: "memory");
}

static __inline void
atomic_subtract_32(__volatile uint32_t *p, uint32_t v)
{
	uint32_t temp;

	__asm __volatile (
		"1:\tll	%0, %3\n\t"		/* load old value */
		"subu	%0, %2\n\t"		/* calculate new value */
		"sc	%0, %1\n\t"		/* attempt to store */
		"beqz	%0, 1b\n\t"		/* spin if failed */
		: "=&r" (temp), "=m" (*p)
		: "r" (v), "m" (*p)
		: "memory");
}

static __inline uint32_t
atomic_readandclear_32(__volatile uint32_t *addr)
{
	uint32_t result,temp;

	__asm __volatile (
		"1:\tll	 %0,%3\n\t"	/* load current value, asserting lock */
		"li	 %1,0\n\t"		/* value to store */
		"sc	 %1,%2\n\t"	/* attempt to store */
		"beqz	 %1, 1b\n\t"		/* if the store failed, spin */
		: "=&r"(result), "=&r"(temp), "=m" (*addr)
		: "m" (*addr)
		: "memory");

	return result;
}

static __inline uint32_t
atomic_readandset_32(__volatile uint32_t *addr, uint32_t value)
{
	uint32_t result,temp;

	__asm __volatile (
		"1:\tll	 %0,%3\n\t"	/* load current value, asserting lock */
		"or      %1,$0,%4\n\t"
		"sc	 %1,%2\n\t"	/* attempt to store */
		"beqz	 %1, 1b\n\t"		/* if the store failed, spin */
		: "=&r"(result), "=&r"(temp), "=m" (*addr)
		: "m" (*addr), "r" (value)
		: "memory");

	return result;
}

/*
 * Atomically compare the value stored at *p with cmpval and if the
 * two values are equal, update the value of *p with newval. Returns
 * zero if the compare failed, nonzero otherwise.
 */
static __inline uint32_t
atomic_cmpset_32(__volatile uint32_t* p, uint32_t cmpval, uint32_t newval)
{
	uint32_t ret;

	__asm __volatile (
		"1:\tll	%0, %4\n\t"		/* load old value */
		"bne %0, %2, 2f\n\t"		/* compare */
		"move %0, %3\n\t"		/* value to store */
		"sc %0, %1\n\t"			/* attempt to store */
		"beqz %0, 1b\n\t"		/* if it failed, spin */
		"j 3f\n\t"
		"2:\n\t"
		"li	%0, 0\n\t"
		"3:\n"
		: "=&r" (ret), "=m" (*p)
		: "r" (cmpval), "r" (newval), "m" (*p)
		: "memory");

	return ret;
}

/*
 * Atomically add the value of v to the integer pointed to by p and return
 * the previous value of *p.
 */
static __inline uint32_t
atomic_fetchadd_32(__volatile uint32_t *p, uint32_t v)
{
	uint32_t value, temp;

	__asm __volatile (
		"1:\tll %0, %1\n\t"		/* load old value */
		"addu %2, %3, %0\n\t"		/* calculate new value */
		"sc %2, %1\n\t"			/* attempt to store */
		"beqz %2, 1b\n\t"		/* spin if failed */
		: "=&r" (value), "=m" (*p), "=&r" (temp)
		: "r" (v), "m" (*p));
	return (value);
}

#endif /* ! _MACHINE_ATOMIC_H_ */
