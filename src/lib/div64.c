/*-
 * Copyright (c) 2014 Marko Zec, University of Zagreb
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


#define	UDIVMOD_SIGNED	0x1
#define	UDIVMOD_DO_MOD	0x2


static __attribute__((optimize("-Os"))) uint64_t
__udivmoddi3(uint64_t a, uint64_t b, int flags)
{
	int neg = 0;
	uint64_t lo = 0;
	uint64_t bit = (b > 0);

	if (flags & UDIVMOD_SIGNED) {
		if ((int64_t)b < 0) {
			b = -(int64_t)b;
			neg = 1;
		}
		if ((int64_t)a < 0) {
			a = -(int64_t)a;
			neg = !neg;
		}
	}

	while (b < a && (int64_t) b > 0) {
		b <<= 1;
		bit <<= 1;
	}
	while (bit != 0) {
		if (a >= b) {
			a -= b;
			lo |= bit;
		}
		bit >>= 1;
		b >>= 1;
	}

	if (__predict_false(flags & UDIVMOD_DO_MOD))
		return (a);
	if (neg)
		return (-lo);
	return (lo);
}


__attribute__((optimize("-Os"))) int64_t
__divdi3(int64_t a, int64_t b)
{

	return (__udivmoddi3(a, b, UDIVMOD_SIGNED));
}
 
 
uint64_t
__moddi3(int64_t a, int64_t b)
{

	return (__udivmoddi3(a, b, UDIVMOD_SIGNED | UDIVMOD_DO_MOD));
}
 
 
uint64_t
__udivdi3(uint64_t a, uint64_t b)
{

	return (__udivmoddi3(a, b, 0));
}
 

uint64_t
__umoddi3(uint64_t a, uint64_t b)
{

	return (__udivmoddi3(a, b, UDIVMOD_DO_MOD));
}
