/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2004-2005 David Schultz <das@FreeBSD.ORG>
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
 */

#ifndef	_FENV_H_
#define	_FENV_H_

#include <sys/_types.h>

#ifndef	__fenv_static
#define	__fenv_static	static
#endif

typedef	__uint32_t	fenv_t;
typedef	__uint32_t	fexcept_t;

/* Exception flags */
#define	_FPUSW_SHIFT	16
#define	FE_INVALID	0x0001
#define	FE_DIVBYZERO	0x0002
#define	FE_OVERFLOW	0x0004
#define	FE_UNDERFLOW	0x0008
#define	FE_INEXACT	0x0010
#define	FE_ALL_EXCEPT	(FE_DIVBYZERO | FE_INEXACT | \
			 FE_INVALID | FE_OVERFLOW | FE_UNDERFLOW)

/* Rounding modes */
#define	FE_TONEAREST	0x0000
#define	FE_TOWARDZERO	0x0001
#define	FE_UPWARD	0x0002
#define	FE_DOWNWARD	0x0003
#define	_ROUND_MASK	(FE_TONEAREST | FE_DOWNWARD | \
			 FE_UPWARD | FE_TOWARDZERO)
__BEGIN_DECLS

/* Default floating-point environment */
extern const fenv_t	__fe_dfl_env;
#define	FE_DFL_ENV	(&__fe_dfl_env)

/* We need to be able to map status flag positions to mask flag positions */
#define	_ENABLE_SHIFT	5
#define	_ENABLE_MASK	(FE_ALL_EXCEPT << _ENABLE_SHIFT)

#if !defined(__mips_soft_float) && !defined(__mips_hard_float) && !defined(__riscv_float_abi_soft) && !defined(__riscv_float_abi_double)
#error compiler didnt set soft/hard float macros
#endif

int feclearexcept(int __excepts);
int fegetexceptflag(fexcept_t *__flagp, int __excepts);
int fesetexceptflag(const fexcept_t *__flagp, int __excepts);
int feraiseexcept(int __excepts);
int fetestexcept(int __excepts);
int fegetround(void);
int fesetround(int __round);
int fegetenv(fenv_t *__envp);
int feholdexcept(fenv_t *__envp);
int fesetenv(const fenv_t *__envp);
int feupdateenv(const fenv_t *__envp);

#if __BSD_VISIBLE

/* We currently provide no external definitions of the functions below. */

int feenableexcept(int __mask);
int fedisableexcept(int __mask);
int fegetexcept(void);

#endif /* __BSD_VISIBLE */

__END_DECLS

#endif	/* !_FENV_H_ */
