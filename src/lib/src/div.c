/*-
 * Copyright (c) 2013 Marko Zec, University of Zagreb
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
 * $Id$
 */


/*
 * Using -Os optimization produces both the fastest and the most compact
 * division, so we override whatever optimization option was requested
 * at gcc invocation with __attribute__((optimize("-Os"))).
 */

#define	OPTIMIZED_DIVSI3

#define	UDIVMOD_SIGNED	0x1
#define	UDIVMOD_DO_MOD	0x2


#define	UDIVMOD_BODY()							\
	lo = 0;								\
	uint32_t bit = (b > 0);						\
									\
	while (b < a && (int) b > 0) {					\
		b <<= 1;						\
		bit <<= 1;						\
	}								\
	while (bit != 0) {						\
		if (a >= b) {						\
			a -= b;						\
			lo |= bit;					\
		}							\
		bit >>= 1;						\
		b >>= 1;						\
	}


static __attribute__((optimize("-Os"))) uint32_t
__udivmodsi3(uint32_t a, uint32_t b, int flags)
{
#ifndef OPTIMIZED_DIVSI3
	int neg = 0;
#endif
	uint32_t lo;

	if (flags & UDIVMOD_SIGNED) {
		if ((int)b < 0) {
			b = -(int)b;
#ifndef OPTIMIZED_DIVSI3
			neg = 1;
#endif
		}
		if ((int)a < 0) {
			a = -(int)a;
#ifndef OPTIMIZED_DIVSI3
			neg = !neg;
#endif
		}
	}

	UDIVMOD_BODY();

	if (__predict_false(flags & UDIVMOD_DO_MOD))
		return (a);
#ifndef OPTIMIZED_DIVSI3
	if (neg)
		return (-lo);
#endif
	return (lo);
}


__attribute__((optimize("-Os"))) int32_t
__divsi3(uint32_t a, uint32_t b)
{
#ifdef OPTIMIZED_DIVSI3
	int neg = 0;
	uint32_t lo;

	if ((int)a < 0) {
		a = -(int)a;
		neg = 1;
	}
	if ((int)b < 0) {
		b = -(int)b;
		neg = !neg;
	}

	UDIVMOD_BODY();

	if (neg)
		return (-lo);
	return (lo);
#else
	return (__udivmodsi3(a, b, UDIVMOD_SIGNED));
#endif /* OPTIMIZED_DIVSI3 */
}
 
 
uint32_t
__modsi3(int32_t a, int32_t b)
{

	return (__udivmodsi3(a, b, UDIVMOD_SIGNED | UDIVMOD_DO_MOD));
}
 
 
uint32_t
__udivsi3(uint32_t a, uint32_t b)
{

	return (__udivmodsi3(a, b, 0));
}
 

uint32_t
__umodsi3(uint32_t a, uint32_t b)
{

	return (__udivmodsi3(a, b, UDIVMOD_DO_MOD));
}
