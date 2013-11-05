/*-
 * Copyright (c) 2013 Marko Zec
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

#ifndef _IO_H_
#define	_IO_H_


#define	IO_BASE		-32768

#define	IO_ADDR(a)	(IO_BASE + (a))

#define	IO_GPIO_DATA	IO_ADDR(0x00)	/* word, RW */
#define	IO_GPIO_CTL	IO_ADDR(0x04)	/* word, WR */
#define	IO_LED		IO_ADDR(0x10)	/* byte, WR */
#define	IO_PUSHBTN	IO_ADDR(0x10)	/* byte, RD */
#define	IO_DIPSW	IO_ADDR(0x11)	/* byte, RD */
#define	IO_LCD_DB	IO_ADDR(0x12)	/* byte, WR */
#define	IO_LCD_CTRL	IO_ADDR(0x13)	/* byte, WR */
#define	IO_SIO_BYTE	IO_ADDR(0x20)	/* byte, RW */
#define	IO_SIO_STATUS	IO_ADDR(0x21)	/* byte, RD */
#define	IO_SIO_BAUD	IO_ADDR(0x22)	/* half, WR */
#define	IO_SPI_FLASH	IO_ADDR(0x30)	/* half, RW */
#define	IO_SPI_SDCARD	IO_ADDR(0x34)	/* half, RW */
#define	IO_FB		IO_ADDR(0x40)	/* word, WR */
#define	IO_PCM_CUR	IO_ADDR(0x50)	/* word, RD */
#define	IO_PCM_FIRST	IO_ADDR(0x50)	/* word, WR */
#define	IO_PCM_LAST	IO_ADDR(0x54)	/* word, WR */
#define	IO_PCM_FREQ	IO_ADDR(0x58)	/* word, WR */
#define	IO_PCM_VOLUME	IO_ADDR(0x5c)	/* half, WR */
#define	IO_CPU_RESET	IO_ADDR(0xf0)	/* byte, WR */


/* SIO status bitmask */
#define	SIO_TX_BUSY	0x4
#define	SIO_RX_OVERRUN	0x2
#define	SIO_RX_FULL	0x1

/* Pushbutton input bitmask */
#define	ROT_A		0x40
#define	ROT_B		0x20
#define	BTN_CENTER	0x10
#define	BTN_UP		0x08
#define	BTN_DOWN	0x04
#define	BTN_LEFT	0x02
#define	BTN_RIGHT	0x01

/* PMOD output mask */
#define	PMOD_J1_MASK	0x0f
#define	PMOD_J2_MASK	0xf0

/* LCD control output bitmask */
#define	LCD_CTRL_E	0x4
#define	LCD_CTRL_RS	0x2
#define	LCD_CTRL_RW	0x1


#if !defined(__ASSEMBLER__)

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

/* XXX this doesn't belong here... */
#include <mips/cpuregs.h>
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

#endif /* !_IO_H_ */

