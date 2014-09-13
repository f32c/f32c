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

#ifndef _MIPS_IO_H_
#define	_MIPS_IO_H_

#if !defined(__ASSEMBLER__)

#include <mips/cpuregs.h>

/* Load / store macros */

#define	SB(data, offset, addr)						\
	__asm __volatile (						\
		"sb %0, %1(%2)"						\
		:							\
		: "r" (data), "i" (offset), "r" (addr)			\
	)

#define	SH(data, offset, addr)						\
	__asm __volatile (						\
		"sh %0, %1(%2)"						\
		:							\
		: "r" (data), "i" (offset), "r" (addr)			\
	)

#define	SW(data, offset, addr)						\
	__asm __volatile (						\
		"sw %0, %1(%2)"						\
		:							\
		: "r" (data), "i" (offset), "r" (addr)			\
	)

#define	LB(data, offset, addr)						\
	__asm __volatile (						\
		"lb %0, %1(%2)"						\
		: "=r" (data)						\
		: "i" (offset), "r" (addr)				\
	)

#define	LH(data, offset, addr)						\
	__asm __volatile (						\
		"lh %0, %1(%2)"						\
		: "=r" (data)						\
		: "i" (offset), "r" (addr)				\
	)

#define	LW(data, offset, addr)						\
	__asm __volatile (						\
		"lw %0, %1(%2)"						\
		: "=r" (data)						\
		: "i" (offset), "r" (addr)				\
	)

/* I/O macros */

#define	OUTB(port, data)					   \
	__asm __volatile ("sb %0, %1($0)"	/* IO_BASE = 0xf* */ \
		:				/* outputs */	   \
		: "r" (data), "i" (port))	/* inputs */

#define	OUTH(port, data)					   \
	__asm __volatile ("sh %0, %1($0)"	/* IO_BASE = 0xf* */ \
		:				/* outputs */	   \
		: "r" (data), "i" (port))	/* inputs */

#define	OUTW(port, data)					   \
	__asm __volatile ("sw %0, %1($0)"	/* IO_BASE = 0xf* */ \
		:				/* outputs */	   \
		: "r" (data), "i" (port))	/* inputs */

#define	INB(data, port)						   \
	__asm __volatile ("lb %0, %1($0)"	/* IO_BASE = 0xf* */ \
		: "=r" (data)			/* outputs */	   \
		: "i" (port))			/* inputs */

#define	INH(data, port)						   \
	__asm __volatile ("lh %0, %1($0)"	/* IO_BASE = 0xf* */ \
		: "=r" (data)			/* outputs */	   \
		: "i" (port))			/* inputs */

#define	INW(data, port)						   \
	__asm __volatile ("lw %0, %1($0)"	/* IO_BASE = 0xf* */ \
		: "=r" (data)			/* outputs */	   \
		: "i" (port))			/* inputs */

/*
 * Declaration of misc. IO functions.
 */

#define	RDTSC(var)						\
	__asm __volatile ("mfc0 %0, $%1"			\
		: "=r" (var)			/* outputs */	\
		: "i" (MIPS_COP_0_COUNT))	/* inputs */

#define	DELAY(ticks) 						\
	__asm __volatile__ (					\
		".set noreorder;"				\
		".set noat;"					\
		"	li	$1, -2;"			\
		"	and	$1, $1, %0;"			\
		"1:	bnez	$1, 1b;"			\
		"	addiu	$1, $1, -2;"			\
		".set at;"					\
		".set reorder;"					\
		:						\
		: "r" (ticks)					\
	)

#endif /* __ASSEMBLER__ */

#endif /* !_MIPS_IO_H_ */
