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
 */

#ifndef _STRINGS_H_
#define	_STRINGS_H_

int	 strcasecmp(const char *, const char *) __pure;
int	 strncasecmp(const char *, const char *, size_t) __pure;

static __inline __pure2 int
ffs(int mask)
{

	return (__builtin_ffs((u_int)mask));
}

static __inline __pure2 int
ffsl(long mask)
{

	return (__builtin_ffsl((u_long)mask));
}

static __inline __pure2 int
ffsll(long long mask)
{

	return (__builtin_ffsll((unsigned long long)mask));
}

static __inline __pure2 int
fls(int mask)
{

	return (mask == 0 ? 0 :
	    8 * sizeof(mask) - __builtin_clz((u_int)mask));
}

static __inline __pure2 int
flsl(long mask)
{

	return (mask == 0 ? 0 :
	    8 * sizeof(mask) - __builtin_clzl((u_long)mask));
}

static __inline __pure2 int
flsll(long long mask)
{

	return (mask == 0 ? 0 :
	    8 * sizeof(mask) - __builtin_clzll((unsigned long long)mask));
}
#endif /* _STRINGS_H_ */
