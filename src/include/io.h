/*-
 * Copyright (c) 2013-2015 Marko Zec, University of Zagreb
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

#ifdef __mips__
#include <mips/io.h>
#endif
#ifdef __riscv__
#include <riscv/io.h>
#endif


#define	IO_BASE		0xfffff800

#define	IO_ADDR(a)	(IO_BASE | (a))

#define	IO_GPIO_DATA	IO_ADDR(0x000)	/* word, RW */
#define	IO_GPIO_CTL	IO_ADDR(0x004)	/* word, WR */
#define	IO_GPIO_RISE_IF	IO_ADDR(0x008)	/* word, RW (clear only) */
#define	IO_GPIO_RISE_IE	IO_ADDR(0x00C)	/* word, RW */
#define	IO_GPIO_FALL_IF	IO_ADDR(0x010)	/* word, RW (clear only) */
#define	IO_GPIO_FALL_IE	IO_ADDR(0x014)	/* word, RW */

#define	IO_TIMER	IO_ADDR(0x100)	/* 16-byte, WR */

#define	IO_SIO_BYTE	IO_ADDR(0x300)	/* byte, RW */
#define	IO_SIO_STATUS	IO_ADDR(0x301)	/* byte, RD */
#define	IO_SIO_BAUD	IO_ADDR(0x302)	/* half, WR */

#define	IO_SPI_FLASH	IO_ADDR(0x340)	/* half, RW */
#define	IO_SPI_SDCARD	IO_ADDR(0x350)	/* half, RW */

#define	IO_FB		IO_ADDR(0x380)	/* word, WR */

#define	IO_PCM_CUR	IO_ADDR(0x3A0)	/* word, RD */
#define	IO_PCM_FIRST	IO_ADDR(0x3A0)	/* word, WR */
#define	IO_PCM_LAST	IO_ADDR(0x3A4)	/* word, WR */
#define	IO_PCM_FREQ	IO_ADDR(0x3A8)	/* word, WR */
#define	IO_PCM_VOLUME	IO_ADDR(0x3AC)	/* half, WR */

#define	IO_LEGO_DATA	IO_ADDR(0x520)	/* byte, WR */
#define	IO_LEGO_CTL	IO_ADDR(0x521)	/* byte, WR */

#define	IO_PUSHBTN	IO_ADDR(0x700)	/* word, RD */
#define	IO_DIPSW	IO_ADDR(0x702)	/* word, RD */
#define	IO_LED		IO_ADDR(0x704)	/* word, WR */
#define	IO_LCD		IO_ADDR(0x706)	/* word, WR */

#define	IO_CPU_RESET	IO_ADDR(0x7F0)	/* byte, WR */


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
#define	LCD_DATA	0x0f
#define	LCD_RS		0x10
#define	LCD_E		0x20

#endif /* !_IO_H_ */

